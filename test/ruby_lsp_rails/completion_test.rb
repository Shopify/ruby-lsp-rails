# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class CompletionTest < ActiveSupport::TestCase
      setup do
        @message_queue = Thread::Queue.new
      end

      def teardown
        T.must(@message_queue).close
      end

      test "..." do
        response = generate_completions_for_source(<<~RUBY, { line: 3, character: 15 })
          # typed: false

          def foo
            redirect_to u
          end
        RUBY

        assert_equal(2, response.size)

        # assert_equal("file:///fake.rb", response[0].uri)
        # assert_equal(5, response[0].range.start.line)
        # assert_equal(2, response[0].range.start.character)
        # assert_equal(5, response[0].range.end.line)
        # assert_equal(14, response[0].range.end.character)

        # assert_equal("file:///fake.rb", response[1].uri)
        # assert_equal(6, response[1].range.start.line)
        # assert_equal(2, response[1].range.start.character)
        # assert_equal(6, response[1].range.end.line)
        # assert_equal(14, response[1].range.end.character)
      end

      private

      def generate_completions_for_source(source, position)
        with_server(source) do |server, uri|
          server.process_message(
            id: 1,
            method: "textDocument/completion",
            params: { textDocument: { uri: uri }, position: position },
          )

          server.pop_response.response
        end
      end
    end
  end
end
