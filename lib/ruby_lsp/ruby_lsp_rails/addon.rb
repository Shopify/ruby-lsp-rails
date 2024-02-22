# typed: strict
# frozen_string_literal: true

require "ruby_lsp/addon"

require_relative "runner_client"
require_relative "hover"
require_relative "code_lens"

module RubyLsp
  module Rails
    class Addon < ::RubyLsp::Addon
      extend T::Sig

      sig { returns(RunnerClient) }
      def client
        @client ||= T.let(
          if defined?(Rails)
            RunnerClient.create_client
          else
            NullClient.new
          end,
          T.nilable(T.any(RunnerClient, NullClient)),
        )
      end

      sig { override.params(message_queue: Thread::Queue).void }
      def activate(message_queue)
        # Eagerly initialize the client in a thread. This allows the indexing from the Ruby LSP to continue running even
        # while we boot large Rails applications in the background
        Thread.new { client }
      end

      sig { override.void }
      def deactivate
        client.shutdown
      end

      # Creates a new CodeLens listener. This method is invoked on every CodeLens request
      sig do
        override.params(
          response_builder: ResponseBuilders::CollectionResponseBuilder[Interface::CodeLens],
          uri: URI::Generic,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def create_code_lens_listener(response_builder, uri, dispatcher)
        CodeLens.new(response_builder, uri, dispatcher)
      end

      sig do
        override.params(
          response_builder: ResponseBuilders::Hover,
          nesting: T::Array[String],
          index: RubyIndexer::Index,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def create_hover_listener(response_builder, nesting, index, dispatcher)
        Hover.new(client, response_builder, nesting, index, dispatcher)
      end

      sig { override.returns(String) }
      def name
        "Ruby LSP Rails"
      end
    end
  end
end
