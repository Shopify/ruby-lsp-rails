# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class ModelsController < ApplicationController
      extend T::Sig

      sig { returns(T.untyped) }
      def show
        const = Object.const_get(params[:id]) # rubocop:disable Sorbet/ConstantsFromStrings

        if const < ActiveRecord::Base
          begin
            schema_file = ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(const.connection.pool.db_config)
          rescue => e
            warn("Could not locate schema: #{e.message}")
          end

          render(json: {
            columns: const.columns.map { |column| [column.name, column.type] },
            schema_file: schema_file,
          })
        else
          head(:not_found)
        end
      rescue NameError, ActiveRecord::TableNotSpecified
        head(:not_found)
      end
    end
  end
end
