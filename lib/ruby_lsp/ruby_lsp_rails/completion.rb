# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    # ![Definition demo](../../definition.gif)
    #
    # TODO: docs
    class Completion
      extend T::Sig
      include Requests::Support::Common

      sig do
        params(
          client: RunnerClient,
          response_builder: ResponseBuilders::CollectionResponseBuilder[Interface::CompletionItem],
          index: RubyIndexer::Index,
          nesting: T::Array[String],
          dispatcher: Prism::Dispatcher,
          uri: URI::Generic,
        ).void
      end
      def initialize(client, response_builder, index, nesting, dispatcher, uri)
        @client = client
        @response_builder = response_builder
        @index = index
        @nesting = nesting
        @uri = uri
        $stderr.puts "Completion initialized"

        dispatcher.register(self, :on_call_node_enter)
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        @client.routes.fetch(:result).each do |helper_name|
          label_details = Interface::CompletionItemLabelDetails.new(description: "Route")
          @response_builder << Interface::CompletionItem.new(label: helper_name, label_details: label_details)
        end
      end
    end
  end
end
