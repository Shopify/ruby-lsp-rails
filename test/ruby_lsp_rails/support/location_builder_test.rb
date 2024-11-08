# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    module Support
      class LocationBuilderTest < Minitest::Test
        test "line_location_from_s raises argument error if invalid string given" do
          assert_raises(ArgumentError) { LocationBuilder.line_location_from_s("banana") }
        end

        test "line_location_from_s returns location based on location string" do
          location = LocationBuilder.line_location_from_s("/path/to/file.rb:3")

          assert_equal("file:///path/to/file.rb", location.uri)
          assert_equal(2, location.range.start.line)
          assert_equal(2, location.range.end.line)
        end
      end
    end
  end
end
