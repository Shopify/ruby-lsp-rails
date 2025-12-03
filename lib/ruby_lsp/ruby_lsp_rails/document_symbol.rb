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
      include Requests::Support::Common
      include ActiveSupportTestCaseHelper

      #: (ResponseBuilders::DocumentSymbol response_builder, Prism::Dispatcher dispatcher) -> void
      def initialize(response_builder, dispatcher)
        @response_builder = response_builder
        @namespace_stack = [] #: Array[String]
        @inside_schema = false #: bool

        dispatcher.register(
          self,
          :on_call_node_enter,
          :on_call_node_leave,
          :on_class_node_enter,
          :on_class_node_leave,
          :on_module_node_enter,
          :on_module_node_leave,
        )
      end

      #: (Prism::CallNode node) -> void
      def on_call_node_enter(node)
        message = node.message
        return unless message

        @inside_schema = true if node_is_schema_define?(node)

        handle_schema_table(node)

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

        case message
        when *Support::Callbacks::ALL, "validate"
          handle_all_arg_types(node, message)
        when "validates", "validates!", "validates_each", "belongs_to", "has_one", "has_many",
          "has_and_belongs_to_many", "attr_readonly", "scope"
          handle_symbol_and_string_arg_types(node, message)
        when "validates_with"
          handle_class_arg_types(node, message)
        end
      end

      #: (Prism::ClassNode node) -> void
      def on_class_node_enter(node)
        add_to_namespace_stack(node)
      end

      #: (Prism::ClassNode node) -> void
      def on_class_node_leave(node)
        remove_from_namespace_stack(node)
      end

      #: (Prism::ModuleNode node) -> void
      def on_module_node_enter(node)
        add_to_namespace_stack(node)
      end

      #: (Prism::ModuleNode node) -> void
      def on_module_node_leave(node)
        remove_from_namespace_stack(node)
      end

      private

      #: ((Prism::ClassNode | Prism::ModuleNode) node) -> void
      def add_to_namespace_stack(node)
        @namespace_stack << node.constant_path.slice
      end

      #: ((Prism::ClassNode | Prism::ModuleNode) node) -> void
      def remove_from_namespace_stack(node)
        @namespace_stack.delete(node.constant_path.slice)
      end

      #: (Prism::CallNode node, String message) -> void
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
              selection_range: range_from_location(
                argument.value_loc, #: as !nil
              ),
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

            name = constant_name(arg_receiver) if arg_receiver.is_a?(Prism::ConstantReadNode) ||
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

      #: (Prism::CallNode node, String message) -> void
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
              selection_range: range_from_location(
                argument.value_loc, #: as !nil
              ),
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

      #: (Prism::CallNode node, String message) -> void
      def handle_class_arg_types(node, message)
        arguments = node.arguments&.arguments
        return unless arguments&.any?

        arguments.each do |argument|
          case argument
          when Prism::ConstantReadNode, Prism::ConstantPathNode
            name = constant_name(argument)
            next unless name

            append_document_symbol(
              name: "#{message} #{name}",
              range: range_from_location(argument.location),
              selection_range: range_from_location(argument.location),
            )
          end
        end
      end

      #: (Prism::CallNode node) -> void
      def handle_schema_table(node)
        return unless @inside_schema
        return unless node.message == "create_table"

        table_name_argument = node.arguments&.arguments&.first

        return unless table_name_argument

        case table_name_argument
        when Prism::SymbolNode
          name = table_name_argument.value
          return unless name

          append_document_symbol(
            name: name,
            range: range_from_location(table_name_argument.location),
            selection_range: range_from_location(
              table_name_argument.value_loc, #: as !nil
            ),
          )
        when Prism::StringNode
          name = table_name_argument.content
          return if name.empty?

          append_document_symbol(
            name: name,
            range: range_from_location(table_name_argument.location),
            selection_range: range_from_location(table_name_argument.content_loc),
          )
        end
      end

      #: (name: String, range: RubyLsp::Interface::Range, selection_range: RubyLsp::Interface::Range) -> void
      def append_document_symbol(name:, range:, selection_range:)
        @response_builder.last.children << RubyLsp::Interface::DocumentSymbol.new(
          name: name,
          kind: RubyLsp::Constant::SymbolKind::METHOD,
          range: range,
          selection_range: selection_range,
        )
      end

      #: (Prism::CallNode node) -> bool
      def node_is_schema_define?(node)
        return false if node.message != "define"

        schema_node = node.receiver
        return false unless schema_node.is_a?(Prism::CallNode)

        active_record_node = schema_node.receiver
        return false unless active_record_node.is_a?(Prism::ConstantPathNode)

        constant_name(active_record_node) == "ActiveRecord::Schema"
      end
    end
  end
end
