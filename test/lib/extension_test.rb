# typed: true
# frozen_string_literal: true

require "test_helper"

module RailsRubyLsp
  class ExtensionTest < ActiveSupport::TestCase
    test "name returns extension name" do
      extension = Extension.new
      assert_equal("Rails Ruby LSP", extension.name)
    end

    test "activate checks if Rails server is running" do
      rails_client = stub("rails_client", check_if_server_is_running!: true)

      RailsRubyLsp::RailsClient.stubs(instance: rails_client)
      extension = Extension.new
      assert_predicate(extension, :activate)
    end
  end
end
