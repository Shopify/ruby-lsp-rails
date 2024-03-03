# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    module ActiveSupportTestCaseHelper
      extend T::Sig

      sig { params(node: Prism::CallNode).returns(T.nilable(String)) }
      def extract_test_case_name(node)
        message_value = node.message
        return unless message_value == "test" || message_value == "it"

        arguments = node.arguments&.arguments
        return unless arguments&.any?

        first_argument = arguments.first

        content = case first_argument
        when Prism::InterpolatedStringNode
          parts = first_argument.parts

          if parts.all? { |part| part.is_a?(Prism::StringNode) }
            T.cast(parts, T::Array[Prism::StringNode]).map(&:content).join
          end
        when Prism::StringNode
          first_argument.content
        end

        if content && !content.empty?
          content
        end
      end
    end
  end
end
