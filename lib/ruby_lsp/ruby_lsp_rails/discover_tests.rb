# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class DiscoverTests
      include Requests::Support::Common

      # @override
      #: (ResponseBuilders::TestCollection response_builder, Prism::Dispatcher dispatcher, URI::Generic uri) -> void
      def initialize(response_builder, dispatcher, uri)
        @response_builder = response_builder
        dispatcher.register(
          self,
          :on_call_node_enter, # e.g. `test "..."`
        )
      end

      #: (Prism::CallNode node) -> void
      def on_call_node_enter(node)
      end
    end
  end
end
