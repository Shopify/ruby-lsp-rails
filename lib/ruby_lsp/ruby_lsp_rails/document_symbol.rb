# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    # ![Document Symbol demo](../../document_symbol.gif)
    #
    # The [document symbol](https://microsoft.github.io/language-server-protocol/specification#textDocument_documentSymbol)
    # request allows users to navigate between ActiveSupport test cases with VS Code's "Go to Symbol" feature.
    class DocumentSymbol
      extend T::Sig
      include Requests::Support::Common
      include ActiveSupportTestCaseHelper

      MODEL_CALLBACKS = T.let(
        [
          "before_validation",
          "after_validation",
          "before_save",
          "around_save",
          "after_save",
          "before_create",
          "around_create",
          "after_create",
          "after_commit",
          "after_rollback",
          "before_update",
          "around_update",
          "after_update",
          "before_destroy",
          "around_destroy",
          "after_destroy",
          "after_initialize",
          "after_find",
          "after_touch",
        ].freeze,
        T::Array[String],
      )

      CONTROLLER_CALLBACKS = T.let(
        [
          "after_action",
          "append_after_action",
          "append_around_action",
          "append_before_action",
          "around_action",
          "before_action",
          "prepend_after_action",
          "prepend_around_action",
          "prepend_before_action",
          "skip_after_action",
          "skip_around_action",
          "skip_before_action",
        ].freeze,
        T::Array[String],
      )

      JOB_CALLBACKS = T.let(
        [
          "after_enqueue",
          "after_perform",
          "around_enqueue",
          "around_perform",
          "before_enqueue",
          "before_perform",
        ].freeze,
        T::Array[String],
      )

      CALLBACKS = T.let((MODEL_CALLBACKS + CONTROLLER_CALLBACKS + JOB_CALLBACKS).freeze, T::Array[String])

      sig do
        params(
          response_builder: ResponseBuilders::DocumentSymbol,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def initialize(response_builder, dispatcher)
        @response_builder = response_builder

        dispatcher.register(self, :on_call_node_enter)
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
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
        when *CALLBACKS, "validate"
          handle_all_arg_types(node, T.must(message))
        when "validates", "validates!", "validates_each"
          handle_symbol_and_string_arg_types(node, T.must(message))
        when "validates_with"
          handle_class_arg_types(node, T.must(message))
        end
      end

      private

      sig { params(node: Prism::CallNode, message: String).void }
      def handle_all_arg_types(node, message)
        block = node.block

        if block
          append_document_symbol(
            name: "#{message}(<anonymous>)",
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
              name: "#{message}(#{name})",
              range: range_from_location(argument.location),
              selection_range: range_from_location(T.must(argument.value_loc)),
            )
          when Prism::StringNode
            name = argument.content
            next if name.empty?

            append_document_symbol(
              name: "#{message}(#{name})",
              range: range_from_location(argument.location),
              selection_range: range_from_location(argument.content_loc),
            )
          when Prism::LambdaNode
            append_document_symbol(
              name: "#{message}(<anonymous>)",
              range: range_from_location(node.location),
              selection_range: range_from_location(argument.location),
            )
          when Prism::CallNode
            next unless argument.name == :new

            arg_receiver = argument.receiver

            name = arg_receiver.name if arg_receiver.is_a?(Prism::ConstantReadNode)
            name = arg_receiver.full_name if arg_receiver.is_a?(Prism::ConstantPathNode)
            next unless name

            append_document_symbol(
              name: "#{message}(#{name})",
              range: range_from_location(argument.location),
              selection_range: range_from_location(argument.location),
            )
          when Prism::ConstantReadNode, Prism::ConstantPathNode
            name = argument.full_name
            next if name.empty?

            append_document_symbol(
              name: "#{message}(#{name})",
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
              name: "#{message}(#{name})",
              range: range_from_location(argument.location),
              selection_range: range_from_location(T.must(argument.value_loc)),
            )
          when Prism::StringNode
            name = argument.content
            next if name.empty?

            append_document_symbol(
              name: "#{message}(#{name})",
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
              name: "#{message}(#{name})",
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
