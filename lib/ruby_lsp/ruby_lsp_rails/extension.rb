# typed: strict
# frozen_string_literal: true

require "ruby_lsp/extension"

require_relative "rails_client"
require_relative "hover"
require_relative "code_lens"
require_relative "document_symbol"

module RubyLsp
  module Rails
    class Extension < ::RubyLsp::Extension
      extend T::Sig

      sig { returns(RailsClient) }
      def client
        @client ||= T.let(RailsClient.new, T.nilable(RailsClient))
      end

      sig { override.void }
      def activate
        client.check_if_server_is_running!
      end

      sig { override.void }
      def deactivate; end

      # Creates a new CodeLens listener. This method is invoked on every CodeLens request
      sig do
        override.params(
          uri: URI::Generic,
          emitter: EventEmitter,
          message_queue: Thread::Queue,
        ).returns(T.nilable(Listener[T::Array[Interface::CodeLens]]))
      end
      def create_code_lens_listener(uri, emitter, message_queue)
        CodeLens.new(uri, emitter, message_queue)
      end

      sig do
        override.params(
          emitter: EventEmitter,
          message_queue: Thread::Queue,
        ).returns(T.nilable(Listener[T.nilable(Interface::Hover)]))
      end
      def create_hover_listener(emitter, message_queue)
        Hover.new(client, emitter, message_queue)
      end

      sig do
        override.params(
          emitter: EventEmitter,
          message_queue: Thread::Queue,
        ).returns(T.nilable(Listener[T::Array[Interface::DocumentSymbol]]))
      end
      def create_document_symbol_listener(emitter, message_queue)
        DocumentSymbol.new(emitter, message_queue)
      end

      sig { override.returns(String) }
      def name
        "Ruby LSP Rails"
      end
    end
  end
end
