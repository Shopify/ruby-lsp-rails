# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class AddonTest < ActiveSupport::TestCase
      test "name returns addon name" do
        addon = Addon.new
        assert_equal("Ruby LSP Rails", addon.name)
      end

      test "activate checks if Rails server is running" do
        rails_client = stub("rails_client", check_if_server_is_running!: true)

        RubyLsp::Rails::RailsClient.stubs(instance: rails_client)
        addon = Addon.new
        assert_predicate(addon, :activate)
      end
    end
  end
end
