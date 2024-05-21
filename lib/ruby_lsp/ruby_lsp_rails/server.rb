# typed: false
# frozen_string_literal: true

require "json"

# NOTE: We should avoid printing to stderr since it causes problems. We never read the standard error pipe from the
# client, so it will become full and eventually hang or crash. Instead, return a response with an `error` key.

module RubyLsp
  module Rails
    class Server
      VOID = Object.new

      def initialize
        $stdin.sync = true
        $stdout.sync = true
        $stdin.binmode
        $stdout.binmode
        @running = true
      end

      def start
        initialize_result = { result: { message: "ok" } }.to_json
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
        else
          VOID
        end
      rescue => e
        { error: e.full_message(highlight: false) }
      end

      private

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

        association_klass = case params[:association_type].intern
        when :has_many
          ActiveRecord::Associations::Builder::HasMany.build(const, params[:association_name].intern, nil, {}).klass
        when :belongs_to
          ActiveRecord::Associations::Builder::BelongsTo.build(const, params[:association_name].intern, nil, {}).klass
        when :has_one
          ActiveRecord::Associations::Builder::HasOne.build(const, params[:association_name].intern, nil, {}).klass
        when :has_and_belongs_to_many
          ActiveRecord::Reflection::HasAndBelongsToManyReflection.new(params[:association_name], nil, {}, const).klass
        else
          return { error: "Unsupported association type #{params[:association_type]}" }
        end

        source_location = Object.const_source_location(association_klass.to_s)

        {
          result: {
            location: source_location.first + ":" + source_location.second.to_s,
          },
        }
      rescue NameError => e
        {
          result: {
            error: e.message,
          },
        }
      end

      def active_record_model?(const)
        !!(
          const &&
            defined?(ActiveRecord) &&
            ActiveRecord::Base > const && # We do this 'backwards' in case the class overwrites `<`
          !const.abstract_class?
        )
      end
    end
  end
end

RubyLsp::Rails::Server.new.start if ARGV.first == "start"
