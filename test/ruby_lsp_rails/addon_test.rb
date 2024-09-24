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
    end
  end
end
