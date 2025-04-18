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
require_relative "rails_test_style"
require_relative "completion"
require_relative "indexing_enhancement"

module RubyLsp
  module Rails
    class Addon < ::RubyLsp::Addon
      RUN_MIGRATIONS_TITLE = "Run Migrations"

      #: -> void
      def initialize
        super

        # We first initialize the client as a NullClient, so that we can start the server in a background thread. Until
        # the real client is initialized, features that depend on it will not be blocked by using the NullClient
        @rails_runner_client = T.let(NullClient.new, RunnerClient)
        @global_state = T.let(nil, T.nilable(GlobalState))
        @outgoing_queue = T.let(nil, T.nilable(Thread::Queue))
        @settings = T.let(
          {
            enablePendingMigrationsPrompt: true,
          },
          T::Hash[Symbol, T.untyped],
        )
        @addon_mutex = T.let(Mutex.new, Mutex)
        @client_mutex = T.let(Mutex.new, Mutex)
        @client_mutex.lock

        Thread.new do
          @addon_mutex.synchronize do
            # We need to ensure the Rails client is fully loaded before we activate the server addons
            @client_mutex.synchronize do
              @rails_runner_client = RunnerClient.create_client(T.must(@outgoing_queue), T.must(@global_state))
            end
            offer_to_run_pending_migrations
          end
        end
      end

      #: -> RunnerClient
      def rails_runner_client
        @addon_mutex.synchronize { @rails_runner_client }
      end

      # @override
      #: (GlobalState global_state, Thread::Queue outgoing_queue) -> void
      def activate(global_state, outgoing_queue)
        @global_state = global_state
        @outgoing_queue = outgoing_queue
        @outgoing_queue << Notification.window_log_message("Activating Ruby LSP Rails add-on v#{VERSION}")

        addon_settings = @global_state.settings_for_addon(name)
        @settings.merge!(addon_settings) if addon_settings

        register_additional_file_watchers(global_state: global_state, outgoing_queue: outgoing_queue)

        # Start booting the real client in a background thread. Until this completes, the client will be a NullClient
        @client_mutex.unlock
      end

      # @override
      #: -> void
      def deactivate
        @rails_runner_client.shutdown
      end

      # @override
      #: -> String
      def version
        VERSION
      end

      # @override
      #: (ResponseBuilders::TestCollection response_builder, Prism::Dispatcher dispatcher, URI::Generic uri) -> void
      def create_discover_tests_listener(response_builder, dispatcher, uri)
        return unless @global_state

        RailsTestStyle.new(@rails_runner_client, response_builder, @global_state, dispatcher, uri)
      end

      # @override
      #: (Array[Hash[Symbol, untyped]]) -> Array[String]
      def resolve_test_commands(items)
        RailsTestStyle.resolve_test_commands(items)
      end

      # Creates a new CodeLens listener. This method is invoked on every CodeLens request
      # @override
      #: (ResponseBuilders::CollectionResponseBuilder[Interface::CodeLens] response_builder, URI::Generic uri, Prism::Dispatcher dispatcher) -> void
      def create_code_lens_listener(response_builder, uri, dispatcher)
        return unless @global_state

        CodeLens.new(@rails_runner_client, @global_state, response_builder, uri, dispatcher)
      end

      # @override
      #: (ResponseBuilders::Hover response_builder, NodeContext node_context, Prism::Dispatcher dispatcher) -> void
      def create_hover_listener(response_builder, node_context, dispatcher)
        return unless @global_state

        Hover.new(@rails_runner_client, response_builder, node_context, @global_state, dispatcher)
      end

      # @override
      #: (ResponseBuilders::DocumentSymbol response_builder, Prism::Dispatcher dispatcher) -> Object
      def create_document_symbol_listener(response_builder, dispatcher)
        DocumentSymbol.new(response_builder, dispatcher)
      end

      # @override
      #: (ResponseBuilders::CollectionResponseBuilder[(Interface::Location | Interface::LocationLink)] response_builder, URI::Generic uri, NodeContext node_context, Prism::Dispatcher dispatcher) -> void
      def create_definition_listener(response_builder, uri, node_context, dispatcher)
        return unless @global_state

        Definition.new(@rails_runner_client, response_builder, node_context, @global_state.index, dispatcher)
      end

      # @override
      #: (ResponseBuilders::CollectionResponseBuilder[Interface::CompletionItem] response_builder, NodeContext node_context, Prism::Dispatcher dispatcher, URI::Generic uri) -> void
      def create_completion_listener(response_builder, node_context, dispatcher, uri)
        Completion.new(@rails_runner_client, response_builder, node_context, dispatcher, uri)
      end

      #: (Array[{uri: String, type: Integer}] changes) -> void
      def workspace_did_change_watched_files(changes)
        if changes.any? { |c| c[:uri].end_with?("db/schema.rb") || c[:uri].end_with?("structure.sql") }
          @rails_runner_client.trigger_reload
        end

        if changes.any? do |c|
             %r{db/migrate/.*\.rb}.match?(c[:uri]) && c[:type] != Constant::FileChangeType::CHANGED
           end

          offer_to_run_pending_migrations
        end
      end

      # @override
      #: -> String
      def name
        "Ruby LSP Rails"
      end

      # @override
      #: (String title) -> void
      def handle_window_show_message_response(title)
        if title == RUN_MIGRATIONS_TITLE

          begin_progress("run-migrations", "Running Migrations")
          response = @rails_runner_client.run_migrations

          if response && @outgoing_queue
            if response[:status] == 0
              # Both log the message and show it as part of progress because sometimes running migrations is so fast you
              # can't see the progress notification
              @outgoing_queue << Notification.window_log_message(response[:message])
              report_progress("run-migrations", message: response[:message])
            else
              @outgoing_queue << Notification.window_show_message(
                "Migrations failed to run\n\n#{response[:message]}",
                type: Constant::MessageType::ERROR,
              )
            end
          end

          end_progress("run-migrations")
        end
      end

      private

      #: (String id, String title, ?percentage: Integer?, ?message: String?) -> void
      def begin_progress(id, title, percentage: nil, message: nil)
        return unless @global_state&.client_capabilities&.supports_progress && @outgoing_queue

        @outgoing_queue << Request.new(
          id: "progress-request-#{id}",
          method: "window/workDoneProgress/create",
          params: Interface::WorkDoneProgressCreateParams.new(token: id),
        )

        @outgoing_queue << Notification.progress_begin(
          id,
          title,
          percentage: percentage,
          message: "#{percentage}% completed",
        )
      end

      #: (String id, ?percentage: Integer?, ?message: String?) -> void
      def report_progress(id, percentage: nil, message: nil)
        return unless @global_state&.client_capabilities&.supports_progress && @outgoing_queue

        @outgoing_queue << Notification.progress_report(id, percentage: percentage, message: message)
      end

      #: (String id) -> void
      def end_progress(id)
        return unless @global_state&.client_capabilities&.supports_progress && @outgoing_queue

        @outgoing_queue << Notification.progress_end(id)
      end

      #: (global_state: GlobalState, outgoing_queue: Thread::Queue) -> void
      def register_additional_file_watchers(global_state:, outgoing_queue:)
        return unless global_state.client_capabilities.supports_watching_files

        outgoing_queue << Request.new(
          id: "ruby-lsp-rails-file-watcher",
          method: "client/registerCapability",
          params: Interface::RegistrationParams.new(
            registrations: [
              Interface::Registration.new(
                id: "workspace/didChangeWatchedFilesRails",
                method: "workspace/didChangeWatchedFiles",
                register_options: Interface::DidChangeWatchedFilesRegistrationOptions.new(
                  watchers: [structure_sql_file_watcher, fixture_file_watcher],
                ),
              ),
            ],
          ),
        )
      end

      #: -> Interface::FileSystemWatcher
      def structure_sql_file_watcher
        Interface::FileSystemWatcher.new(
          glob_pattern: "**/*structure.sql",
          kind: Constant::WatchKind::CREATE | Constant::WatchKind::CHANGE | Constant::WatchKind::DELETE,
        )
      end

      #: -> Interface::FileSystemWatcher
      def fixture_file_watcher
        Interface::FileSystemWatcher.new(
          glob_pattern: "**/fixtures/**/*.{yml,yaml,yml.erb,yaml.erb}",
          kind: Constant::WatchKind::CREATE | Constant::WatchKind::CHANGE | Constant::WatchKind::DELETE,
        )
      end

      #: -> void
      def offer_to_run_pending_migrations
        return unless @outgoing_queue
        return unless @global_state&.client_capabilities&.window_show_message_supports_extra_properties
        return unless @settings[:enablePendingMigrationsPrompt]

        migration_message = @rails_runner_client.pending_migrations_message
        return unless migration_message

        @outgoing_queue << Request.new(
          id: "rails-pending-migrations",
          method: "window/showMessageRequest",
          params: {
            type: Constant::MessageType::INFO,
            message: migration_message,
            actions: [
              { title: RUN_MIGRATIONS_TITLE, addon_name: name, method: "window/showMessageRequest" },
              { title: "Cancel", addon_name: name, method: "window/showMessageRequest" },
            ],
          },
        )
      end
    end
  end
end
