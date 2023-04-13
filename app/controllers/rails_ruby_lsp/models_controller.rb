# typed: strict
# frozen_string_literal: true

module RailsRubyLsp
  class ModelsController < ApplicationController
    extend T::Sig

    sig { returns(T.untyped) }
    def show
      const = Object.const_get(params[:id]) # rubocop:disable Sorbet/ConstantsFromStrings

      if const < ActiveRecord::Base
        render(json: {
          columns: const.columns.map { |column| [column.name, column.type] },
        })
      else
        head(:not_found)
      end
    rescue NameError, ActiveRecord::TableNotSpecified
      head(:not_found)
    end
  end
end
