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

      sig { void }
      def initialize
        $stdin.sync = true
        $stdout.sync = true
        @running = T.let(true, T::Boolean)
      end

      sig { void }
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

      sig do
        params(
          request: String,
          params: T.nilable(T::Hash[Symbol, T.untyped]),
        ).returns(T.any(Object, T::Hash[Symbol, T.untyped]))
      end
      def execute(request, params)
        case request
        when "shutdown"
          @running = false
          VOID
        when "model"
          resolve_database_info_from_model(T.must(params).fetch(:name))
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
        { error: e.full_message(highlight: false) }
      end
    end
  end
end

RubyLsp::Rails::Server.new.start if ARGV.first == "start"
