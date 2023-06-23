# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class CodeLensTest < ActiveSupport::TestCase
      setup do
        @message_queue = Thread::Queue.new
      end

      def teardown
        T.must(@message_queue).close
      end

      test "recognizes Rails Active Support test cases" do
        store = RubyLsp::Store.new
        store.set(uri: "file:///fake.rb", source: <<~RUBY, version: 1)
          class Test < ActiveSupport::TestCase
            test "an example" do
              # test body
            end
          end
        RUBY

        response = RubyLsp::Executor.new(store, @message_queue).execute({
          method: "textDocument/codeLens",
          params: { textDocument: { uri: "file:///fake.rb" }, position: { line: 0, character: 0 } },
        }).response

        # The first 3 responses are for the test class.
        # The last 3 are for the test declaration.
        assert_equal(6, response.size)
        assert_match("Run", response[3].command.title)
        assert_equal("bin/rails test /fake.rb:2", response[3].command.arguments[2])
        assert_match("Run In Terminal", response[4].command.title)
        assert_match("Debug", response[5].command.title)
      end

      test "recognizes plain test cases" do
        store = RubyLsp::Store.new
        store.set(uri: "file:///fake.rb", source: <<~RUBY, version: 1)
          class Test < ActiveSupport::TestCase
            def test_example
              # test body
            end
          end
        RUBY

        response = RubyLsp::Executor.new(store, @message_queue).execute({
          method: "textDocument/codeLens",
          params: { textDocument: { uri: "file:///fake.rb" }, position: { line: 0, character: 0 } },
        }).response

        # The first 3 responses are for the test declaration.
        # The last 3 are for the test class.
        assert_equal(6, response.size)
        assert_match("Run", response[3].command.title)
        assert_equal("bin/rails test /fake.rb:2", response[3].command.arguments[2])
        assert_match("Run In Terminal", response[4].command.title)
        assert_match("Debug", response[5].command.title)
      end
    end
  end
end
