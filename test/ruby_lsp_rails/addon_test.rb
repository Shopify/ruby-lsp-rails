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
    end
  end
end
