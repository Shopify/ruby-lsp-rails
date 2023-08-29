# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class HoverTest < ActiveSupport::TestCase
      setup do
        File.write("#{Dir.pwd}/test/dummy/tmp/app_uri.txt", "http://localhost:3000")
        @client = RailsClient.new
        @message_queue = Thread::Queue.new

        # Build the Rails documents index ahead of time
        capture_io do
          Support::RailsDocumentClient.send(:search_index)
        end
      end

      teardown do
        @message_queue.close
      end

      test "hook returns model column information" do
        expected_response = {
          schema_file: "#{@client.root}/db/schema.rb",
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
        listener = Hover.new(@client, emitter, @message_queue)

        stub_http_request("200", expected_response.to_json)
        @client.stubs(check_if_server_is_running!: true)
        emitter.emit_for_target(Const("User"))

        assert_equal(<<~CONTENT, T.must(listener.response).contents.value)
          [Schema](file://#{@client.root}/db/schema.rb)

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
          schema_file: "#{@client.root}/db/structure.sql",
          columns: [],
        }
        emitter = RubyLsp::EventEmitter.new
        listener = Hover.new(@client, emitter, @message_queue)

        stub_http_request("200", expected_response.to_json)
        @client.stubs(check_if_server_is_running!: true)
        emitter.emit_for_target(Const("User"))

        assert_includes(
          T.must(listener.response).contents.value,
          "[Schema](file://#{@client.root}/db/structure.sql)",
        )
      end

      test "handles neither `db/structure.sql` nor `db/schema.rb` being present" do
        expected_response = {
          schema_file: nil,
          columns: [],
        }

        emitter = RubyLsp::EventEmitter.new
        listener = Hover.new(@client, emitter, @message_queue)

        stub_http_request("200", expected_response.to_json)
        @client.stubs(check_if_server_is_running!: true)
        emitter.emit_for_target(Const("User"))

        refute_match(/Schema/, T.must(listener.response).contents.value)
      end

      test "shows documentation for routes DSLs" do
        emitter = RubyLsp::EventEmitter.new
        listener = Hover.new(@client, emitter, @message_queue)
        emitter.emit_for_target(Command(Ident("root"), "projects#index", nil))

        response = T.must(listener.response).contents.value
        assert_match(/\[Rails Document: `ActionDispatch::Routing::Mapper::Resources#root`\]/, response)
        assert_match(%r{\(https://api\.rubyonrails\.org/.*\.html#method-i-root\)}, response)
      end

      test "shows documentation for controller DSLs" do
        emitter = RubyLsp::EventEmitter.new
        listener = Hover.new(@client, emitter, @message_queue)
        emitter.emit_for_target(Command(Ident("before_action"), "foo", nil))

        response = T.must(listener.response).contents.value
        assert_match(/\[Rails Document: `AbstractController::Callbacks::ClassMethods#before_action`\]/, response)
        assert_match(%r{\(https://api\.rubyonrails\.org/.*\.html#method-i-before_action\)}, response)
      end

      test "shows documentation for job DSLs" do
        emitter = RubyLsp::EventEmitter.new
        listener = Hover.new(@client, emitter, @message_queue)
        emitter.emit_for_target(Command(Ident("queue_as"), "default", nil))

        response = T.must(listener.response).contents.value
        assert_match(/\[Rails Document: `ActiveJob::QueueName::ClassMethods#queue_as`\]/, response)
        assert_match(%r{\(https://api\.rubyonrails\.org/.*\.html#method-i-queue_as\)}, response)
      end

      test "shows documentation for model DSLs" do
        emitter = RubyLsp::EventEmitter.new
        listener = Hover.new(@client, emitter, @message_queue)
        emitter.emit_for_target(CallNode(nil, ".", Ident("validate"), "foo"))

        response = T.must(listener.response).contents.value
        assert_match(/\[Rails Document: `ActiveModel::EachValidator#validate`\]/, response)
        assert_match(%r{\(https://api\.rubyonrails\.org/.*\.html#method-i-validate\)}, response)
      end

      test "shows documentation for Rails constants" do
        emitter = RubyLsp::EventEmitter.new
        listener = Hover.new(@client, emitter, @message_queue)
        emitter.emit_for_target(ConstPathRef(VarRef(Const("ActiveRecord")), Const("Base")))

        response = T.must(listener.response).contents.value
        assert_match(/\[Rails Document: `ActiveRecord::Base`\]/, response)
        assert_match(%r{\(https://api\.rubyonrails\.org/.*Base\.html\)}, response)
      end
    end
  end
end
