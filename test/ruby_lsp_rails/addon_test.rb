# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class AddonTest < ActiveSupport::TestCase
      test "name returns add-on name" do
        addon = Addon.new
        assert_equal("Ruby LSP Rails", addon.name)
      end

      test "sends reload notification if db/schema.rb is changed" do
        changes = [
          {
            uri: "file://#{dummy_root}/db/schema.rb",
            type: RubyLsp::Constant::FileChangeType::CHANGED,
          },
        ]

        RunnerClient.any_instance.expects(:send_notification).with("reload").once
        addon = Addon.new
        addon.workspace_did_change_watched_files(changes)
      end

      test "sends reload notification if a *structure.sql file is changed" do
        changes = [
          {
            uri: "file://#{dummy_root}/db/structure.sql",
            type: RubyLsp::Constant::FileChangeType::CHANGED,
          },
        ]

        RunnerClient.any_instance.expects(:send_notification).with("reload").once
        addon = Addon.new
        addon.workspace_did_change_watched_files(changes)
      end

      test "does not send reload notification if schema is not changed" do
        changes = [
          {
            uri: "file://#{dummy_root}/app/models/foo.rb",
            type: RubyLsp::Constant::FileChangeType::CHANGED,
          },
        ]

        RunnerClient.any_instance.expects(:send_notification).never
        addon = Addon.new
        addon.workspace_did_change_watched_files(changes)
      end

      test "handling window show message response to run migrations" do
        RunnerClient.any_instance.expects(:run_migrations).once.returns({ message: "Ran migrations!", status: 0 })
        outgoing_queue = Thread::Queue.new
        global_state = GlobalState.new
        global_state.apply_options({ capabilities: { window: { workDoneProgress: true } } })

        addon = Addon.new
        addon.activate(global_state, outgoing_queue)

        # Wait until activation is done
        Thread.new do
          addon.rails_runner_client
        end.join

        addon.handle_window_show_message_response("Run Migrations")

        progress_request = pop_message(outgoing_queue) { |message| message.is_a?(Request) }
        assert_instance_of(Request, progress_request)

        progress_begin = pop_message(outgoing_queue) do |message|
          message.is_a?(Notification) && message.method == "$/progress"
        end
        assert_equal("begin", progress_begin.params.value.kind)

        report_log = pop_message(outgoing_queue) do |message|
          message.is_a?(Notification) && message.method == "window/logMessage"
        end
        assert_equal("Ran migrations!", report_log.params.message)

        progress_report = pop_message(outgoing_queue) do |message|
          message.is_a?(Notification) && message.method == "$/progress"
        end
        assert_equal("report", progress_report.params.value.kind)
        assert_equal("Ran migrations!", progress_report.params.value.message)

        progress_end = pop_message(outgoing_queue) do |message|
          message.is_a?(Notification) && message.method == "$/progress"
        end
        assert_equal("end", progress_end.params.value.kind)
      ensure
        T.must(outgoing_queue).close
      end

      test "migration dialog respects enabled setting" do
        outgoing_queue = Thread::Queue.new
        global_state = GlobalState.new
        global_state.apply_options({
          capabilities: { window: { showMessage: { messageActionItem: { additionalPropertiesSupport: true } } } },
          initializationOptions: { addonSettings: { "Ruby LSP Rails": { enablePendingMigrationsPrompt: false } } },
        })

        refute(T.must(global_state.settings_for_addon("Ruby LSP Rails"))[:enablePendingMigrationsPrompt])

        addon = Addon.new
        addon.activate(global_state, outgoing_queue)

        # Wait until activation is done
        Thread.new do
          addon.rails_runner_client
        end.join

        RunnerClient.any_instance.expects(:pending_migrations_message).never
        addon.workspace_did_change_watched_files([
          {
            uri: "file://#{dummy_root}/db/migrate/20210901000000_create_foos.rb",
            type: RubyLsp::Constant::FileChangeType::CREATED,
          },
        ])
      ensure
        T.must(outgoing_queue).close
      end
    end
  end
end
