# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    module Support
      module Associations
        ALL = T.let(
          [
            "belongs_to",
            "has_many",
            "has_one",
            "has_and_belongs_to_many",
          ].freeze,
          T::Array[String],
        )
      end
    end
  end
end
