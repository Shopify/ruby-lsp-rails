# typed: true
# frozen_string_literal: true

require "test_helper"

module RailsRubyLsp
  class HoverTest < ActiveSupport::TestCase
    test "hook returns model column information" do
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

      listener = Hover.new

      stub_http_request("200", expected_response.to_json) do
        RailsClient.instance.stub(:check_if_server_is_running!, true) do
          RubyLsp::EventEmitter.new(listener).emit_for_target(Const("User"))
        end
      end

      assert_equal(<<~CONTENT, T.must(listener.response).contents.value)
        [Schema](file://#{RailsClient.instance.root}/db/schema.rb)

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
