# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    module Support
      module Validations
        ALL = [
          "validate",
          "validates",
          "validates!",
          "validates_each",
          "validates_with",
          "validates_absence_of",
          "validates_acceptance_of",
          "validates_comparison_of",
          "validates_confirmation_of",
          "validates_exclusion_of",
          "validates_format_of",
          "validates_inclusion_of",
          "validates_length_of",
          "validates_numericality_of",
          "validates_presence_of",
          "validates_size_of",
        ].freeze
      end
    end
  end
end
