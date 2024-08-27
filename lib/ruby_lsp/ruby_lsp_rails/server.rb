# typed: false
# frozen_string_literal: true

require "json"

# NOTE: We should avoid printing to stderr since it causes problems. We never read the standard error pipe from the
# client, so it will become full and eventually hang or crash. Instead, return a response with an `error` key.

module RubyLsp
  module Rails
    class InvalidAddonError < RuntimeError
    end

    class Server
      class << self
        def require_server_addon(gem_name)
          require "ruby_lsp/#{gem_name}/addon"
          Object.const_get("RubyLsp::#{gem_name.classify}::Addon") # rubocop:disable Sorbet/ConstantsFromStrings
        rescue LoadError, NameError
          raise InvalidAddonError, "Failed to load addon '#{gem_name}'"
        end
      end

      VOID = Object.new

      def initialize
        $stdin.sync = true
        $stdout.sync = true
        $stderr.sync = true
        $stdin.binmode
        $stdout.binmode
        $stderr.binmode
        @running = true
        @addons = {}
      end

      def start
        # Load routes if they haven't been loaded yet (see https://github.com/rails/rails/pull/51614).
        routes_reloader = ::Rails.application.routes_reloader
        routes_reloader.execute_unless_loaded if routes_reloader&.respond_to?(:execute_unless_loaded)

        initialize_result = { result: { message: "ok", root: ::Rails.root.to_s } }.to_json
        $stdout.write("Content-Length: #{initialize_result.length}\r\n\r\n#{initialize_result}")

        while @running
          headers = $stdin.gets("\r\n\r\n")
          json = $stdin.read(headers[/Content-Length: (\d+)/i, 1].to_i)

          request = JSON.parse(json, symbolize_names: true)
          response = execute(request.fetch(:method), request[:params])
          next if response == VOID

          json_response = response.to_json
          $stdout.write("Content-Length: #{json_response.length}\r\n\r\n#{json_response}")
        end
      end

      def execute(request, params)
        if request.include?(".")
          execute_for_addon(request, params)
        else
          execute_for_ruby_lsp_rails(request, params)
        end
      end

      private

      def execute_for_addon(request, params)
        addon, command = request.split(".")

        unless addon.present? && command.present?
          return { error: "Invalid request format: #{request}" }
        end

        begin
          @addons[addon.to_sym] ||= self.class.require_server_addon(addon).new
        rescue InvalidAddonError
          return { error: "Addon '#{addon}' setup failed" }
        end

        # TODO: Verify error is seen
        unless @addons[addon.to_sym]
          return { error: "Loading addon '#{addon}' failed" }
        end

        File.open("ruby-lsp-rails.txt", "a") do |f|
          addon = @addons[addon.to_sym]
          # TODO: why didn't I see an error when 'dsl' was typoed?

          addon.send(command, params)
        end
        VOID
      end

      def execute_for_ruby_lsp_rails(request, params)
        case request
        when "shutdown"
          @running = false
          VOID
        when "model"
          resolve_database_info_from_model(params.fetch(:name))
        when "association_target_location"
          resolve_association_target(params)
        when "reload"
          ::Rails.application.reloader.reload!
          VOID
        when "route_location"
          route_location(params.fetch(:name))
        when "route_info"
          resolve_route_info(params)
        else
          VOID
        end
      rescue => e
        { error: e.full_message(highlight: false) }
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
