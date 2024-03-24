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
          response_builder: ResponseBuilders::CollectionResponseBuilder[Interface::CompletionItem],
          index: RubyIndexer::Index,
          nesting: T::Array[String],
          dispatcher: Prism::Dispatcher,
          uri: URI::Generic,
        ).void
      end
      def initialize(response_builder, index, nesting, dispatcher, uri)
        @response_builder = response_builder
        $stderr.puts "Completion initialized"

        # dispatcher.register(self, :on_call_node_enter)
      end
    end
  end
end
