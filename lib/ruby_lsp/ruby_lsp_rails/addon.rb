# typed: strict
# frozen_string_literal: true

require "ruby_lsp/addon"

require_relative "../../ruby_lsp_rails/version"
require_relative "support/active_support_test_case_helper"
require_relative "support/associations"
require_relative "support/callbacks"
require_relative "support/location_builder"
require_relative "runner_client"
require_relative "hover"
require_relative "code_lens"
require_relative "document_symbol"
require_relative "definition"
require_relative "indexing_enhancement"

module RubyLsp
  module Rails
    class Addon < ::RubyLsp::Addon
      extend T::Sig

      sig { void }
      def initialize
        super

        # We first initialize the client as a NullClient, so that we can start the server in a background thread. Until
        # the real client is initialized, features that depend on it will not be blocked by using the NullClient
        @client = T.let(NullClient.new, RunnerClient)
      end

      sig { override.params(global_state: GlobalState, message_queue: Thread::Queue).void }
      def activate(global_state, message_queue)
        @global_state = T.let(global_state, T.nilable(RubyLsp::GlobalState))
        $stderr.puts("Activating Ruby LSP Rails addon v#{VERSION}")
        # Start booting the real client in a background thread. Until this completes, the client will be a NullClient
        Thread.new { @client = RunnerClient.create_client }
        register_additional_file_watchers(global_state: global_state, message_queue: message_queue)

        T.must(@global_state).index.register_enhancement(IndexingEnhancement.new)
      end

      sig { override.void }
      def deactivate
        @client.shutdown
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
        CodeLens.new(@client, T.must(@global_state), response_builder, uri, dispatcher)
      end

      sig do
        override.params(
          response_builder: ResponseBuilders::Hover,
          node_context: NodeContext,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def create_hover_listener(response_builder, node_context, dispatcher)
        Hover.new(@client, response_builder, node_context, T.must(@global_state), dispatcher)
      end

      sig do
        override.params(
          response_builder: ResponseBuilders::DocumentSymbol,
          dispatcher: Prism::Dispatcher,
        ).returns(Object)
      end
      def create_document_symbol_listener(response_builder, dispatcher)
        DocumentSymbol.new(response_builder, dispatcher)
      end

      sig do
        override.params(
          response_builder: ResponseBuilders::CollectionResponseBuilder[T.any(
            Interface::Location, Interface::LocationLink
          )],
          uri: URI::Generic,
          node_context: NodeContext,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def create_definition_listener(response_builder, uri, node_context, dispatcher)
        index = T.must(@global_state).index
        Definition.new(@client, response_builder, node_context, index, dispatcher)
      end

      sig { params(changes: T::Array[{ uri: String, type: Integer }]).void }
      def workspace_did_change_watched_files(changes)
        if changes.any? do |change|
             change[:uri].end_with?("db/schema.rb") || change[:uri].end_with?("structure.sql")
           end
          @client.trigger_reload
        end
      end

      sig { params(global_state: GlobalState, message_queue: Thread::Queue).void }
      def register_additional_file_watchers(global_state:, message_queue:)
        return unless global_state.supports_watching_files

        message_queue << Request.new(
          id: "ruby-lsp-rails-file-watcher",
          method: "client/registerCapability",
          params: Interface::RegistrationParams.new(
            registrations: [
              Interface::Registration.new(
                id: "workspace/didChangeWatchedFilesRails",
                method: "workspace/didChangeWatchedFiles",
                register_options: Interface::DidChangeWatchedFilesRegistrationOptions.new(
                  watchers: [
                    Interface::FileSystemWatcher.new(
                      glob_pattern: "**/*structure.sql",
                      kind: Constant::WatchKind::CREATE | Constant::WatchKind::CHANGE | Constant::WatchKind::DELETE,
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
      end

      sig { override.returns(String) }
      def name
        "Ruby LSP Rails"
      end
    end
  end
end
