# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  class RailsTest < Minitest::Test
    test "it has a version number" do
      assert RubyLsp::Rails::VERSION
    end
  end
end
