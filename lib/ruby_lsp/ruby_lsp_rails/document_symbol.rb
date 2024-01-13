# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    # ![Document Symbol demo](../../document_symbol.gif)
    #
    # The [document symbol](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_documentSymbol)
    # request allows users to navigate between ActiveSupport test cases with VS Code's "Go to Symbol" feature.
    class DocumentSymbol
      extend T::Sig
      include Requests::Support::Common

      sig do
        params(
          response_builder: ResponseBuilders::DocumentSymbol,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def initialize(response_builder, dispatcher)
        @_response = T.let(nil, NilClass)
        @response_builder = response_builder

        dispatcher.register(self, :on_call_node_enter)
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        message_value = node.message
        return unless message_value == "test" || message_value == "it"

        return unless node.arguments

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

        return unless content && !content.empty?

        @response_builder.last.children << RubyLsp::Interface::DocumentSymbol.new(
          name: content,
          kind: LanguageServer::Protocol::Constant::SymbolKind::METHOD,
          selection_range: range_from_node(node),
          range: range_from_node(node),
        )
      end
    end
  end
end
