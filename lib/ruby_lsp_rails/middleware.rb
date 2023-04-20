# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class Middleware
      extend T::Sig

      PATH_REGEXP = %r{/ruby_lsp_rails/models/(?<model_name>.+)}

      sig { params(app: T.untyped).void }
      def initialize(app)
        @app = app
      end

      sig { params(env: T::Hash[T.untyped, T.untyped]).returns(T::Array[T.untyped]) }
      def call(env)
        request = ActionDispatch::Request.new(env)
        # TODO: improve the model name regex
        match = request.path.match(PATH_REGEXP)

        if match
          resolve_database_info_from_model(match[:model_name])
        else
          @app.call(env)
        end
      rescue
        @app.call(env)
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
            columns: const.columns.map { |column| [column.name, column.type] },
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
