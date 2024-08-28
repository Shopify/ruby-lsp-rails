# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    # ![Document Symbol demo](../../document_symbol.gif)
    #
    # The [document symbol](https://microsoft.github.io/language-server-protocol/specification#textDocument_documentSymbol)
    # request allows users to navigate between associations, validations, callbacks and ActiveSupport test cases with
    # VS Code's "Go to Symbol" feature.
    class DocumentSymbol
      extend T::Sig
      include Requests::Support::Common
      include ActiveSupportTestCaseHelper

      sig do
        params(
          response_builder: ResponseBuilders::DocumentSymbol,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def initialize(response_builder, dispatcher)
        @response_builder = response_builder
        @namespace_stack = T.let([], T::Array[String])

        dispatcher.register(
          self,
          :on_call_node_enter,
          :on_class_node_enter,
          :on_class_node_leave,
          :on_module_node_enter,
          :on_module_node_leave,
        )
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        return if @namespace_stack.empty?

        content = extract_test_case_name(node)

        if content
          append_document_symbol(
            name: content,
            selection_range: range_from_node(node),
            range: range_from_node(node),
          )
        end

        receiver = node.receiver
        return if receiver && !receiver.is_a?(Prism::SelfNode)

        message = node.message
        case message
        when *Support::Callbacks::ALL, "validate"
          handle_all_arg_types(node, T.must(message))
        when "validates", "validates!", "validates_each", "belongs_to", "has_one", "has_many",
          "has_and_belongs_to_many", "attr_readonly", "scope"
          handle_symbol_and_string_arg_types(node, T.must(message))
        when "validates_with"
          handle_class_arg_types(node, T.must(message))
        end
      end

      sig { params(node: Prism::ClassNode).void }
      def on_class_node_enter(node)
        add_to_namespace_stack(node)
      end

      sig { params(node: Prism::ClassNode).void }
      def on_class_node_leave(node)
        remove_from_namespace_stack(node)
      end

      sig { params(node: Prism::ModuleNode).void }
      def on_module_node_enter(node)
        add_to_namespace_stack(node)
      end

      sig { params(node: Prism::ModuleNode).void }
      def on_module_node_leave(node)
        remove_from_namespace_stack(node)
      end

      private

      sig { params(node: T.any(Prism::ClassNode, Prism::ModuleNode)).void }
      def add_to_namespace_stack(node)
        @namespace_stack << node.constant_path.slice
      end

      sig { params(node: T.any(Prism::ClassNode, Prism::ModuleNode)).void }
      def remove_from_namespace_stack(node)
        @namespace_stack.delete(node.constant_path.slice)
      end

      sig { params(node: Prism::CallNode, message: String).void }
      def handle_all_arg_types(node, message)
        block = node.block

        if block
          append_document_symbol(
            name: "#{message} <anonymous>",
            range: range_from_location(node.location),
            selection_range: range_from_location(block.location),
          )
          return
        end

        arguments = node.arguments&.arguments
        return unless arguments&.any?

        arguments.each do |argument|
          case argument
          when Prism::SymbolNode
            name = argument.value
            next unless name

            append_document_symbol(
              name: "#{message} :#{name}",
              range: range_from_location(argument.location),
              selection_range: range_from_location(T.must(argument.value_loc)),
            )
          when Prism::StringNode
            name = argument.content
            next if name.empty?

            append_document_symbol(
              name: "#{message} :#{name}",
              range: range_from_location(argument.location),
              selection_range: range_from_location(argument.content_loc),
            )
          when Prism::LambdaNode
            append_document_symbol(
              name: "#{message} <anonymous>",
              range: range_from_location(node.location),
              selection_range: range_from_location(argument.location),
            )
          when Prism::CallNode
            next unless argument.name == :new

            arg_receiver = argument.receiver

            name = arg_receiver.full_name if arg_receiver.is_a?(Prism::ConstantReadNode) ||
              arg_receiver.is_a?(Prism::ConstantPathNode)
            next unless name

            append_document_symbol(
              name: "#{message} #{name}",
              range: range_from_location(argument.location),
              selection_range: range_from_location(argument.location),
            )
          when Prism::ConstantReadNode, Prism::ConstantPathNode
            name = constant_name(argument)
            next unless name
            next if name.empty?

            append_document_symbol(
              name: "#{message} #{name}",
              range: range_from_location(argument.location),
              selection_range: range_from_location(argument.location),
            )
          end
        end
      end

      sig { params(node: Prism::CallNode, message: String).void }
      def handle_symbol_and_string_arg_types(node, message)
        arguments = node.arguments&.arguments
        return unless arguments&.any?

        arguments.each do |argument|
          case argument
          when Prism::SymbolNode
            name = argument.value
            next unless name

            append_document_symbol(
              name: "#{message} :#{name}",
              range: range_from_location(argument.location),
              selection_range: range_from_location(T.must(argument.value_loc)),
            )
          when Prism::StringNode
            name = argument.content
            next if name.empty?

            append_document_symbol(
              name: "#{message} :#{name}",
              range: range_from_location(argument.location),
              selection_range: range_from_location(argument.content_loc),
            )
          end
        end
      end

      sig { params(node: Prism::CallNode, message: String).void }
      def handle_class_arg_types(node, message)
        arguments = node.arguments&.arguments
        return unless arguments&.any?

        arguments.each do |argument|
          case argument
          when Prism::ConstantReadNode, Prism::ConstantPathNode
            name = argument.full_name
            next if name.empty?

            append_document_symbol(
              name: "#{message} #{name}",
              range: range_from_location(argument.location),
              selection_range: range_from_location(argument.location),
            )
          end
        end
      end

      sig do
        params(
          name: String,
          range: RubyLsp::Interface::Range,
          selection_range: RubyLsp::Interface::Range,
        ).void
      end
      def append_document_symbol(name:, range:, selection_range:)
        @response_builder.last.children << RubyLsp::Interface::DocumentSymbol.new(
          name: name,
          kind: RubyLsp::Constant::SymbolKind::METHOD,
          range: range,
          selection_range: selection_range,
        )
      end
    end
  end
end
