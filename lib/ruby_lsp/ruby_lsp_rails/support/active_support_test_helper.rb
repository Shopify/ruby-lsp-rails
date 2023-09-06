# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    module ActiveSupportTestHelper
      extend T::Sig

      sig { params(node: SyntaxTree::Command).returns(T.nilable(String)) }
      def active_support_test_name(node)
        message_value = node.message.value
        return unless message_value == "test" && node.arguments.parts.any?

        first_argument = node.arguments.parts.first

        parts = case first_argument
        when SyntaxTree::StringConcat
          # We only support two lines of concatenation on test names
          if first_argument.left.is_a?(SyntaxTree::StringLiteral) &&
              first_argument.right.is_a?(SyntaxTree::StringLiteral)
            [*first_argument.left.parts, *first_argument.right.parts]
          end
        when SyntaxTree::StringLiteral
          first_argument.parts
        end

        # The test name may be a blank string while the code is being typed
        return if parts.nil? || parts.empty?

        # We can't handle interpolation yet
        return unless parts.all? { |part| part.is_a?(SyntaxTree::TStringContent) }

        test_name = parts.map(&:value).join
        test_name unless test_name.empty?
      end
    end
  end
end
