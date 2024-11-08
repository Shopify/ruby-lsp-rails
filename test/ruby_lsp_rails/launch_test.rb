# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class LaunchTest < Minitest::Test
      test "launching the client succeeds" do
        outgoing_queue = Thread::Queue.new

        client = RunnerClient.create_client(outgoing_queue)
        refute_instance_of(NullClient, client)

        first = pop_log_notification(outgoing_queue, Constant::MessageType::LOG)
        assert_equal("Ruby LSP Rails booting server", first.params.message)

        second = pop_log_notification(outgoing_queue, Constant::MessageType::LOG)
        assert_match("Finished booting Ruby LSP Rails server", second.params.message)

        client.shutdown
        assert_predicate(client, :stopped?)
        outgoing_queue.close
      end
    end
  end
end
