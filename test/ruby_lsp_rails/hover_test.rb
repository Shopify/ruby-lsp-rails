# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class HoverTest < ActiveSupport::TestCase
      setup do
        @message_queue = Thread::Queue.new
      end

      teardown do
        @message_queue.close
      end

      test "hook returns model column information" do
        expected_response = {
          schema_file: "#{RailsClient.instance.root}/db/schema.rb",
          columns: [
            ["id", "integer"],
            ["first_name", "string"],
            ["last_name", "string"],
            ["age", "integer"],
            ["created_at", "datetime"],
            ["updated_at", "datetime"],
          ],
        }

        emitter = RubyLsp::EventEmitter.new
        listener = Hover.new(emitter, @message_queue)

        stub_http_request("200", expected_response.to_json)
        RailsClient.instance.stubs(check_if_server_is_running!: true)
        emitter.emit_for_target(Const("User"))

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

      test "handles `db/structure.sql` instead of `db/schema.rb`" do
        expected_response = {
          schema_file: "#{RailsClient.instance.root}/db/structure.sql",
          columns: [],
        }
        emitter = RubyLsp::EventEmitter.new
        listener = Hover.new(emitter, @message_queue)

        stub_http_request("200", expected_response.to_json)
        RailsClient.instance.stubs(check_if_server_is_running!: true)
        emitter.emit_for_target(Const("User"))

        assert_includes(
          T.must(listener.response).contents.value,
          "[Schema](file://#{RailsClient.instance.root}/db/structure.sql)",
        )
      end

      test "handles neither `db/structure.sql` nor `db/schema.rb` being present" do
        expected_response = {
          schema_file: nil,
          columns: [],
        }

        emitter = RubyLsp::EventEmitter.new
        listener = Hover.new(emitter, @message_queue)

        stub_http_request("200", expected_response.to_json)
        RailsClient.instance.stubs(check_if_server_is_running!: true)
        emitter.emit_for_target(Const("User"))

        refute_match(/Schema/, T.must(listener.response).contents.value)
      end
    end
  end
end
