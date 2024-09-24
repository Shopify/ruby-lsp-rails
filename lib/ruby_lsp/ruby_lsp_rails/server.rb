# typed: false
# frozen_string_literal: true

require "json"

# NOTE: We should avoid printing to stderr since it causes problems. We never read the standard error pipe from the
# client, so it will become full and eventually hang or crash. Instead, return a response with an `error` key.

module RubyLsp
  module Rails
    class ServerAddon
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

      # Write a response back. Can be used for sending notifications to the editor
      def write_response(response)
        json_response = response.to_json
        @stdout.write("Content-Length: #{json_response.length}\r\n\r\n#{json_response}")
      end

      def name
        raise NotImplementedError, "Not implemented!"
      end

      def execute(request, params)
        raise NotImplementedError, "Not implemented!"
      end
    end

    class Server
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
        # Load routes if they haven't been loaded yet (see https://github.com/rails/rails/pull/51614).
        routes_reloader = ::Rails.application.routes_reloader
        routes_reloader.execute_unless_loaded if routes_reloader&.respond_to?(:execute_unless_loaded)

        initialize_result = { result: { message: "ok", root: ::Rails.root.to_s } }.to_json
        @stdout.write("Content-Length: #{initialize_result.length}\r\n\r\n#{initialize_result}")

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
          write_response(resolve_database_info_from_model(params.fetch(:name)))
        when "association_target_location"
          write_response(resolve_association_target(params))
        when "reload"
          ::Rails.application.reloader.reload!
        when "route_location"
          write_response(route_location(params.fetch(:name)))
        when "route_info"
          write_response(resolve_route_info(params))
        when "server_addon/register"
          require params[:server_addon_path]
          ServerAddon.finalize_registrations!(@stdout)
        when "server_addon/delegate"
          server_addon_name = params.delete(:server_addon_name)
          request_name = params.delete(:request_name)
          ServerAddon.delegate(server_addon_name, request_name, params)
        end
      rescue => e
        write_response({ error: e.full_message(highlight: false) })
      end

      private

      def write_response(response)
        json_response = response.to_json
        @stdout.write("Content-Length: #{json_response.length}\r\n\r\n#{json_response}")
      end

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

        if route&.source_location
          file, _, line = route.source_location.rpartition(":")
          body = {
            source_location: [::Rails.root.join(file).to_s, line],
            verb: route.verb,
            path: route.path.spec.to_s,
          }

          { result: body }
        else
          { result: nil }
        end
      end

      # Older versions of Rails don't support `route_source_locations`.
      # We also check that it's enabled.
      if ActionDispatch::Routing::Mapper.respond_to?(:route_source_locations) &&
          ActionDispatch::Routing::Mapper.route_source_locations
        def route_location(name)
          match_data = name.match(/^(.+)(_path|_url)$/)
          return { result: nil } unless match_data

          key = match_data[1]

          # A token could match the _path or _url pattern, but not be an actual route.
          route = ::Rails.application.routes.named_routes.get(key)
          return { result: nil } unless route&.source_location

          {
            result: {
              location: ::Rails.root.join(route.source_location).to_s,
            },
          }
        rescue => e
          { error: e.full_message(highlight: false) }
        end
      else
        def route_location(name)
          { result: nil }
        end
      end

      def resolve_database_info_from_model(model_name)
        const = ActiveSupport::Inflector.safe_constantize(model_name)
        unless active_record_model?(const)
          return {
            result: nil,
          }
        end

        info = {
          result: {
            columns: const.columns.map { |column| [column.name, column.type] },
            primary_keys: Array(const.primary_key),
          },
        }

        if ActiveRecord::Tasks::DatabaseTasks.respond_to?(:schema_dump_path)
          info[:result][:schema_file] =
            ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(const.connection.pool.db_config)

        end
        info
      rescue => e
        { error: e.full_message(highlight: false) }
      end

      def resolve_association_target(params)
        const = ActiveSupport::Inflector.safe_constantize(params[:model_name])
        unless active_record_model?(const)
          return {
            result: nil,
          }
        end

        association_klass = const.reflect_on_association(params[:association_name].intern).klass

        source_location = Object.const_source_location(association_klass.to_s)

        {
          result: {
            location: source_location.first + ":" + source_location.second.to_s,
          },
        }
      rescue NameError
        {
          result: nil,
        }
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
    end
  end
end

RubyLsp::Rails::Server.new.start if ARGV.first == "start"
