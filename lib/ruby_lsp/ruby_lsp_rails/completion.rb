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
          response_builder: ResponseBuilders::CollectionResponseBuilder[T.any(
            Interface::Location, Interface::LocationLink
          )],
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
        if @node_context.call_node&.name == :where
          handle_active_record_where_completions(node)
        end
      end

      private

      sig { params(node: Prism::CallNode).void }
      def handle_active_record_where_completions(node)
        resolved_class = @client.model(@node_context.call_node.receiver&.name)
        return if resolved_class.nil?

        resolved_class[:columns].each do |column|
          @response_builder << Interface::CompletionItem.new(
            label: column[0],
            filter_text: column[0],
            label_details: Interface::CompletionItemLabelDetails.new(
              description: "Filter #{@node_context.call_node.receiver.name} records by #{column[0]}",
            ),
            text_edit: Interface::TextEdit.new(range: 0, new_text: "#{column[0]}:"),
            kind: Constant::CompletionItemKind::FIELD,
          )
        end
      end
    end
  end
end
