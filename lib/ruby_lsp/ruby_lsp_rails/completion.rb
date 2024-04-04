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
          dispatcher: Prism::Dispatcher,
          uri: URI::Generic,
        ).void
      end
      def initialize(client, response_builder, dispatcher, uri)
        @client = client
        @response_builder = response_builder
        @uri = uri

        dispatcher.register(self, :on_call_node_enter)
      end

      # TODO: why on_call_node_enter?
      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        return [] unless valid_for_file_type?

        @client.routes.each do |helper_name|
          # label_details = Interface::CompletionItemLabelDetails.new(description: "Route")
          @response_builder << Interface::CompletionItem.new(
            label: helper_name, detail: "Route", kind: Constant::CompletionItemKind::METHOD,
          )
        end
      end

      private

      sig { returns(T::Boolean) }
      def valid_for_file_type?
        # TODO: check inheritance instead?
        T.must(@uri.path).end_with?("_controller.rb")
      end
    end
  end
end
