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
        when "reload"
          ::Rails.application.reloader.reload!
          VOID
        else
          VOID
        end
      rescue => e
        { error: e.full_message(highlight: false) }
      end

      private

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
