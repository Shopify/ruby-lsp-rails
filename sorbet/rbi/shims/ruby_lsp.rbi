# typed: strict
# frozen_string_literal: true

module RubyIndexer
  class Enhancement
    def initialize(listener)
      @listener = T.let(listener, RubyIndexer::DeclarationListener)
    end
  end
end

module RubyLsp
  module Listeners
    class TestDiscovery
      #: (ResponseBuilders::TestCollection response_builder, GlobalState global_state, URI::Generic uri) -> void
      def initialize(response_builder, global_state, uri)
        @response_builder = response_builder
        @uri = uri
        @index = T.let(T.unsafe(nil), RubyIndexer::Index)
        @visibility_stack = T.let([], T::Array[Symbol])
        @nesting = T.let([], T::Array[String])
      end
    end
  end
end
