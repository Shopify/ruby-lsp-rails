# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class RackApp
      extend T::Sig

      BASE_PATH = "/ruby_lsp_rails/"

      sig { params(env: T::Hash[T.untyped, T.untyped]).returns(T::Array[T.untyped]) }
      def call(env)
        request = ActionDispatch::Request.new(env)
        path = request.path

        route, argument = path.delete_prefix(BASE_PATH).split("/")

        case route
        when "activate"
          [200, { "Content-Type" => "application/json" }, []]
        when "models"
          resolve_database_info_from_model(argument)
        else
          not_found
        end
      end

      private

      sig { params(model_name: String).returns(T::Array[T.untyped]) }
      def resolve_database_info_from_model(model_name)
        const = ActiveSupport::Inflector.safe_constantize(model_name)

        if const && const < ActiveRecord::Base
          begin
            schema_file = ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(const.connection.pool.db_config)
          rescue => e
            warn("Could not locate schema: #{e.message}")
          end

          body = JSON.dump({
            columns: const.columns.map { |column| { name: column.name, type: column.type, comment: column.comment } },
            schema_file: schema_file,
          })

          [200, { "Content-Type" => "application/json" }, [body]]
        else
          not_found
        end
      end

      sig { returns(T::Array[T.untyped]) }
      def not_found
        [404, { "Content-Type" => "text/plain" }, ["Not Found"]]
      end
    end
  end
end
