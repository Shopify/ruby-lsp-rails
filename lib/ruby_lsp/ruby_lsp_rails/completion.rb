# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class Completion
      extend T::Sig
      include Requests::Support::Common

      sig do
        override.params(
          client: RunnerClient,
          response_builder: ResponseBuilders::CollectionResponseBuilder[Interface::CompletionItem],
          node_context: NodeContext,
          dispatcher: Prism::Dispatcher,
          uri: URI::Generic,
        ).void
      end
      def initialize(client, response_builder, node_context, dispatcher, uri)
        @response_builder = response_builder
        @client = client
        @node_context = node_context
        dispatcher.register(
          self,
          :on_call_node_enter,
        )
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        call_node = @node_context.call_node
        return unless call_node

        receiver = call_node.receiver
        if call_node.name == :where && receiver.is_a?(Prism::ConstantReadNode)
          handle_active_record_where_completions(node: node, receiver: receiver)
        end
      end

      private

      sig { params(node: Prism::CallNode, receiver: Prism::ConstantReadNode).void }
      def handle_active_record_where_completions(node:, receiver:)
        resolved_class = @client.model(receiver.name.to_s)
        return if resolved_class.nil?

        arguments = T.must(@node_context.call_node).arguments&.arguments
        indexed_call_node_args = T.let({}, T::Hash[String, Prism::Node])

        if arguments
          indexed_call_node_args = index_call_node_args(arguments: arguments)
          return if indexed_call_node_args.values.any? { |v| v == node }
        end

        range = range_from_location(node.location)

        resolved_class[:columns].each do |column|
          next unless column[0].start_with?(node.name.to_s)
          next if indexed_call_node_args.key?(column[0])

          @response_builder << Interface::CompletionItem.new(
            label: column[0],
            filter_text: column[0],
            label_details: Interface::CompletionItemLabelDetails.new(
              description: "Filter #{receiver.name} records by #{column[0]}",
            ),
            text_edit: Interface::TextEdit.new(range: range, new_text: "#{column[0]}: "),
            kind: Constant::CompletionItemKind::FIELD,
          )
        end
      end

      sig { params(arguments: T::Array[Prism::Node]).returns(T::Hash[String, Prism::Node]) }
      def index_call_node_args(arguments:)
        indexed_call_node_args = {}
        arguments.each do |argument|
          next unless argument.is_a?(Prism::KeywordHashNode)

          argument.elements.each do |e|
            next unless e.is_a?(Prism::AssocNode)

            key = e.key
            if key.is_a?(Prism::SymbolNode)
              indexed_call_node_args[key.value] = e.value
            end
          end
        end
        indexed_call_node_args
      end
    end
  end
end
