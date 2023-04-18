# typed: true
# frozen_string_literal: true

require "test_helper"

module RailsRubyLsp
  class RailsClientTest < ActiveSupport::TestCase
    test "model returns information for the requested model" do
      expected_response = {
        columns: [
          ["id", "integer"],
          ["first_name", "string"],
          ["last_name", "string"],
          ["age", "integer"],
          ["created_at", "datetime"],
          ["updated_at", "datetime"],
        ],
      }

      stub_http_request("200", expected_response.to_json)
      assert_equal(expected_response, RailsClient.instance.model("User"))
    end
  end
end
