# typed: false
# frozen_string_literal: true

require "json"
require "open3"

# NOTE: We should avoid printing to stderr since it causes problems. We never read the standard error pipe from the
# client, so it will become full and eventually hang or crash. Instead, return a response with an `error` key.

module RubyLsp
  module Rails
    module Common
      # Write a message to the client. Can be used for sending notifications to the editor
      def send_message(message)
        json_message = message.to_json
        @stdout.write("Content-Length: #{json_message.length}\r\n\r\n#{json_message}")
      end

      # Log a message to the editor's output panel
      def log_message(message)
        $stderr.puts(message)
      end

      # Sends an error result to a request, if the request failed. DO NOT INVOKE THIS METHOD FOR NOTIFICATIONS! Use
      # `log_message` instead, otherwise the client/server communication will go out of sync
      def send_error_response(message)
        send_message({ error: message })
      end

      # Sends a result back to the client
      def send_result(result)
        send_message({ result: result })
      end

      # Handle possible errors for a request. This should only be used for requests, which means messages that return a
      # response back to the client. Errors are returned as an error object back to the client
      def with_request_error_handling(request_name, &block)
        block.call
      rescue ActiveRecord::ConnectionNotEstablished
        # Since this is a common problem, we show a specific error message to the user, instead of the full stack trace.
        send_error_response("Request #{request_name} failed because database connection was not established.")
      rescue ActiveRecord::NoDatabaseError
        send_error_response("Request #{request_name} failed because the database does not exist.")
      rescue => e
        send_error_response("Request #{request_name} failed:\n#{e.full_message(highlight: false)}")
      end

      # Handle possible errors for a notification. This should only be used for notifications, which means messages that
      # do not return a response back to the client. Errors are logged to the editor's output panel
      def with_notification_error_handling(notification_name, &block)
        block.call
      rescue ActiveRecord::ConnectionNotEstablished
        # Since this is a common problem, we show a specific error message to the user, instead of the full stack trace.
        log_message("Request #{notification_name} failed because database connection was not established.")
      rescue ActiveRecord::NoDatabaseError
        log_message("Request #{notification_name} failed because the database does not exist.")
      rescue => e
        log_message("Request #{notification_name} failed:\n#{e.full_message(highlight: false)}")
      end
    end

    class ServerAddon
      include Common

      @server_addon_classes = []
      @server_addons = {}

      class << self
        # We keep track of runtime server add-ons the same way we track other add-ons, by storing classes that inherit
        # from the base one
        def inherited(child)
          @server_addon_classes << child
          super
        end

        # Delegate `request` with `params` to the server add-on with the given `name`
        def delegate(name, request, params)
          @server_addons[name]&.execute(request, params)
        end

        # Instantiate all server addons and store them in a hash for easy access after we have discovered the classes
        def finalize_registrations!(stdout)
          until @server_addon_classes.empty?
            addon = @server_addon_classes.shift.new(stdout)
            @server_addons[addon.name] = addon
          end
        end
      end

      def initialize(stdout)
        @stdout = stdout
      end

      def name
        raise NotImplementedError, "Not implemented!"
      end

      def execute(request, params)
        raise NotImplementedError, "Not implemented!"
      end
    end

    class Server
      include Common

      def initialize(stdout: $stdout, override_default_output_device: true)
        # Grab references to the original pipes so that we can change the default output device further down
        @stdin = $stdin
        @stdout = stdout
        @stderr = $stderr
        @stdin.sync = true
        @stdout.sync = true
        @stderr.sync = true
        @stdin.binmode
        @stdout.binmode
        @stderr.binmode

        # # Set the default output device to be $stderr. This means that using `puts` by itself will default to printing
        # # to $stderr and only explicit `$stdout.puts` will go to $stdout. This reduces the chance that output coming
        # # from the Rails app will be accidentally sent to the client
        $> = $stderr if override_default_output_device

        @running = true
      end

      def start
        load_routes
        send_result({ message: "ok", root: ::Rails.root.to_s })

        while @running
          headers = @stdin.gets("\r\n\r\n")
          json = @stdin.read(headers[/Content-Length: (\d+)/i, 1].to_i)

          request = JSON.parse(json, symbolize_names: true)
          execute(request.fetch(:method), request[:params])
        end
      end

      def execute(request, params)
        case request
        when "shutdown"
          @running = false
        when "model"
          with_request_error_handling(request) do
            send_result(resolve_database_info_from_model(params.fetch(:name)))
          end
        when "association_target_location"
          with_request_error_handling(request) do
            send_result(resolve_association_target(params))
          end
        when "pending_migrations_message"
          with_request_error_handling(request) do
            send_result({ pending_migrations_message: pending_migrations_message })
          end
        when "run_migrations"
          with_request_error_handling(request) do
            send_result(run_migrations)
          end
        when "reload"
          with_notification_error_handling(request) do
            ::Rails.application.reloader.reload!
          end
        when "route_location"
          with_request_error_handling(request) do
            send_result(route_location(params.fetch(:name)))
          end
        when "route_info"
          with_request_error_handling(request) do
            send_result(resolve_route_info(params))
          end
        when "server_addon/register"
          with_notification_error_handling(request) do
            require params[:server_addon_path]
            ServerAddon.finalize_registrations!(@stdout)
          end
        when "server_addon/delegate"
          server_addon_name = params[:server_addon_name]
          request_name = params[:request_name]

          # Do not wrap this in error handlers. Server add-ons need to have the flexibility to choose if they want to
          # include a response or not as part of error handling, so a blanket approach is not appropriate.
          ServerAddon.delegate(server_addon_name, request_name, params.except(:request_name, :server_addon_name))
        end
      end

      private

      def resolve_route_info(requirements)
        if requirements[:controller]
          requirements[:controller] = requirements.fetch(:controller).underscore.delete_suffix("_controller")
        end

        # In Rails 7.2 we can use `from_requirements, otherwise we fall back to a private API
        route = if ::Rails.application.routes.respond_to?(:from_requirements)
          ::Rails.application.routes.from_requirements(requirements)
        else
          ::Rails.application.routes.routes.find { |route| route.requirements == requirements }
        end

        source_location = route&.respond_to?(:source_location) && route.source_location
        return unless source_location

        file, _, line = source_location.rpartition(":")

        {
          source_location: [::Rails.root.join(file).to_s, line],
          verb: route.verb,
          path: route.path.spec.to_s,
        }
      end

      # Older versions of Rails don't support `route_source_locations`.
      # We also check that it's enabled.
      if ActionDispatch::Routing::Mapper.respond_to?(:route_source_locations) &&
          ActionDispatch::Routing::Mapper.route_source_locations
        def route_location(name)
          # In Rails 8, Rails.application.routes.named_routes is not populated by default
          if ::Rails.application.respond_to?(:reload_routes_unless_loaded)
            ::Rails.application.reload_routes_unless_loaded
          end

          match_data = name.match(/^(.+)(_path|_url)$/)
          return unless match_data

          key = match_data[1]

          # A token could match the _path or _url pattern, but not be an actual route.
          route = ::Rails.application.routes.named_routes.get(key)
          return unless route&.source_location

          { location: ::Rails.root.join(route.source_location).to_s }
        end
      else
        def route_location(name)
          nil
        end
      end

      def resolve_database_info_from_model(model_name)
        const = ActiveSupport::Inflector.safe_constantize(model_name)
        return unless active_record_model?(const)

        info = {
          columns: const.columns.map { |column| [column.name, column.type, column.default, column.null] },
          primary_keys: Array(const.primary_key),
        }

        if ActiveRecord::Tasks::DatabaseTasks.respond_to?(:schema_dump_path)
          info[:schema_file] = ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(const.connection.pool.db_config)
        end

        info
      end

      def resolve_association_target(params)
        const = ActiveSupport::Inflector.safe_constantize(params[:model_name])
        return unless active_record_model?(const)

        association_klass = const.reflect_on_association(params[:association_name].intern).klass
        source_location = Object.const_source_location(association_klass.to_s)

        { location: source_location.first + ":" + source_location.second.to_s }
      rescue NameError
        nil
      end

      def active_record_model?(const)
        !!(
          const &&
            defined?(ActiveRecord) &&
            const.is_a?(Class) &&
            ActiveRecord::Base > const && # We do this 'backwards' in case the class overwrites `<`
          !const.abstract_class?
        )
      end

      def pending_migrations_message
        # `check_all_pending!` is only available since Rails 7.1
        return unless defined?(ActiveRecord) && ActiveRecord::Migration.respond_to?(:check_all_pending!)

        ActiveRecord::Migration.check_all_pending!
        nil
      rescue ActiveRecord::PendingMigrationError => e
        e.message
      end

      def run_migrations
        # Running migrations invokes `load` which will repeatedly load the same files. It's not designed to be invoked
        # multiple times within the same process. To avoid any memory bloat, we run migrations in a separate process
        stdout, status = Open3.capture2(
          { "VERBOSE" => "true" },
          "bundle exec rails db:migrate",
        )

        { message: stdout, status: status.exitstatus }
      end

      def load_routes
        with_notification_error_handling("initial_load_routes") do
          # Load routes if they haven't been loaded yet (see https://github.com/rails/rails/pull/51614).
          routes_reloader = ::Rails.application.routes_reloader
          routes_reloader.execute_unless_loaded if routes_reloader&.respond_to?(:execute_unless_loaded)
        end
      end
    end
  end
end

RubyLsp::Rails::Server.new.start if ARGV.first == "start"
