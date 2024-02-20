# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "json"

begin
  T::Configuration.default_checked_level = :never
  # Suppresses call validation errors
  T::Configuration.call_validation_error_handler = ->(*) {}
  # Suppresses errors caused by T.cast, T.let, T.must, etc.
  T::Configuration.inline_type_error_handler = ->(*) {}
  # Suppresses errors caused by incorrect parameter ordering
  T::Configuration.sig_validation_error_handler = ->(*) {}
rescue
  # Need this rescue so that if another gem has
  # already set the checked level by the time we
  # get to it, we don't fail outright.
  nil
end

# NOTE: We should avoid printing to stderr since it causes problems. We never read the standard error pipe from the
# client, so it will become full and eventually hang or crash. Instead, return a response with an `error` key.

module RubyLsp
  module Rails
    class Server
      VOID = Object.new

      extend T::Sig

      sig { params(model_name: String).returns(T::Hash[Symbol, T.untyped]) }
      def resolve_database_info_from_model(model_name)
        const = ActiveSupport::Inflector.safe_constantize(model_name)
        unless const && defined?(ActiveRecord) && const < ActiveRecord::Base && !const.abstract_class?
          return {
            result: nil,
          }
        end

        info = {
          result: {
            columns: const.columns.map { |column| [column.name, column.type] },
          },
        }

        if ActiveRecord::Tasks::DatabaseTasks.respond_to?(:schema_dump_path)
          info[:result][:schema_file] =
            ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(const.connection.pool.db_config)

        end
        info
      rescue => e
        {
          error: e.message,
        }
      end

      sig { void }
      def start
        $stdin.sync = true
        $stdout.sync = true

        running = T.let(true, T::Boolean)

        while running
          headers = $stdin.gets("\r\n\r\n")
          request = $stdin.read(headers[/Content-Length: (\d+)/i, 1].to_i)

          json = JSON.parse(request, symbolize_names: true)
          request_method = json.fetch(:method)
          params = json[:params]

          response = case request_method
          when "shutdown"
            running = false
            VOID
          when "model"
            resolve_database_info_from_model(params.fetch(:name))
          else
            VOID
          end

          next if response == VOID

          json_response = response.to_json
          $stdout.write("Content-Length: #{json_response.length}\r\n\r\n#{json_response}")
        end
      end
    end
  end
end

RubyLsp::Rails::Server.new.start if ARGV.first == "start"
