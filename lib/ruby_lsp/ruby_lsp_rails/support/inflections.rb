# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    module Inflections
      #: String -> String
      def camelize(string)
        string
          .gsub(/_([a-z])/) { $1.upcase }
          .gsub(/(^|\/)[a-z]/) { $&.upcase }
          .gsub("/", "::")
      end

      #: String -> String
      def underscore(string)
        string
          .gsub(/([a-z])([A-Z])/, "\\1_\\2")
          .gsub("::", "/")
          .downcase
      end
    end
  end
end
