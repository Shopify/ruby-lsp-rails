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
        $stderr.puts("In the new completion class")
        @response_builder = response_builder
        @client = client
        @node_context = node_context
        dispatcher.register(
          self,
          :on_call_node_enter,
        )
        $stderr.puts("After dispatcher being registered")
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        $stderr.puts("Entrered call node")

        $stderr.puts(node.receiver&.name)
        $stderr.puts(node.name)
        $stderr.puts(node.opening_loc&.slice)
        receiver_name = node.receiver&.name
        return if receiver_name.nil?

        resolved_class = @client.model(receiver_name)
        return if resolved_class.nil?

        $stderr.puts("MADEIT")
        $stderr.puts(node.message)
        $stderr.puts(node.arguments)

        resolved_class[:columns].each do |column|
          @response_builder << Interface::CompletionItem.new(
            label: column[0],
            filter_text: column[0],
            label_details: column[0],
            text_edit: Interface::TextEdit.new(range: 0, new_text: column[0]),
            kind: Constant::CompletionItemKind::METHOD,
          )
        end
      end
    end
  end
end
