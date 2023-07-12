# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class ExtensionTest < ActiveSupport::TestCase
      test "name returns extension name" do
        extension = Extension.new
        assert_equal("Ruby LSP Rails", extension.name)
      end

      test "activate checks if Rails server is running" do
        rails_client = stub("rails_client", check_if_server_is_running!: true)

        RubyLsp::Rails::RailsClient.stubs(instance: rails_client)
        extension = Extension.new
        assert_predicate(extension, :activate)
      ensure
        ::RubyLsp::Requests::Hover.listeners.clear
        ::RubyLsp::Requests::CodeLens.listeners.clear
      end
    end
  end
end
