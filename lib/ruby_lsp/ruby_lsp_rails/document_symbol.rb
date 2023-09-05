# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class DocumentSymbol < ::RubyLsp::Listener
      extend T::Sig
      extend T::Generic

      ResponseType = type_member { { fixed: T::Array[::RubyLsp::Interface::DocumentSymbol] } }
      SymbolHierarchyRoot = RubyLsp::Requests::DocumentSymbol::SymbolHierarchyRoot

      sig { override.returns(ResponseType) }
      attr_reader :response

      sig { params(emitter: EventEmitter, message_queue: Thread::Queue).void }
      def initialize(emitter, message_queue)
        @root = T.let(RubyLsp::Requests::DocumentSymbol::SymbolHierarchyRoot.new, SymbolHierarchyRoot)
        @response = T.let(@root.children, ResponseType)
        @stack = T.let(
          [@root],
          T::Array[T.any(SymbolHierarchyRoot, Interface::DocumentSymbol)],
        )
        emitter.register(self, :on_command, :on_class, :after_class)

        super(emitter, message_queue)
      end

      sig { params(node: SyntaxTree::ClassDeclaration).void }
      def on_class(node)
        @stack << create_document_symbol(
          name: full_constant_name(node.constant),
          kind: Constant::SymbolKind::CLASS,
          range_node: node,
          selection_range_node: node.constant,
        )
      end

      sig { params(node: SyntaxTree::ClassDeclaration).void }
      def after_class(node)
        @stack.pop
      end

      sig { params(node: SyntaxTree::Command).void }
      def on_command(node)
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
        return if test_name.empty?

        create_document_symbol(
          name: test_name,
          kind: RubyLsp::Constant::SymbolKind::METHOD,
          range_node: node,
          selection_range_node: node,
        )
      end

      private

      sig do
        params(
          name: String,
          kind: Integer,
          range_node: SyntaxTree::Node,
          selection_range_node: SyntaxTree::Node,
        ).returns(Interface::DocumentSymbol)
      end
      def create_document_symbol(name:, kind:, range_node:, selection_range_node:)
        symbol = Interface::DocumentSymbol.new(
          name: name,
          kind: kind,
          range: range_from_syntax_tree_node(range_node),
          selection_range: range_from_syntax_tree_node(selection_range_node),
          children: [],
        )

        T.must(@stack.last).children << symbol

        symbol
      end
    end
  end
end
