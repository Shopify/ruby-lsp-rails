# typed: true
# frozen_string_literal: true

require "test_helper"

module RailsRubyLsp
  class HoverTest < ActiveSupport::TestCase
    test "hook returns model column information" do
      response = T.let(nil, T.nilable(String))
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

      stub_http_request("200", expected_response.to_json) do
        RailsClient.instance.stub(:check_if_server_is_running!, true) do
          response = Hover.run(Const("User"))
        end
      end

      assert_equal(<<~CONTENT, response)
        [Schema](file:///Users/viniciusstock/src/github.com/Shopify/rails_ruby_lsp/test/dummy/db/schema.rb)

        **id**: integer

        **first_name**: string

        **last_name**: string

        **age**: integer

        **created_at**: datetime

        **updated_at**: datetime
      CONTENT
    end
  end
end
