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
        response = generate_code_lens_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            test "an example" do
              # test body
            end
          end
        RUBY

        # The first 3 responses are for the test class.
        # The last 3 are for the test declaration.
        assert_equal(6, response.size)
        assert_match("Run", response[3].command.title)
        assert_equal("bin/rails test /fake.rb:2", response[3].command.arguments[2])
        assert_match("Run In Terminal", response[4].command.title)
        assert_match("Debug", response[5].command.title)
      end

      test "recognizes multiline escaped strings" do
        response = generate_code_lens_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            test "an example" \
              "multiline" do
              # test body
            end
          end
        RUBY

        # The first 3 responses are for the test class.
        # The last 3 are for the test declaration.
        assert_equal(6, response.size)
        assert_match("Run", response[3].command.title)
        assert_equal("bin/rails test /fake.rb:2", response[3].command.arguments[2])
        assert_match("Run In Terminal", response[4].command.title)
        assert_match("Debug", response[5].command.title)
      end

      test "ignores unnamed tests (empty string)" do
        response = generate_code_lens_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            test "" do
              # test body
            end
          end
        RUBY

        # The 3 responses are for the test class, none for the test declaration.
        assert_equal(3, response.size)
      end

      test "ignores tests with interpolation in their names" do
        # Note that we need to quote the heredoc RUBY marker to prevent interpolation when defining the test.
        response = generate_code_lens_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            test "before \#{1 + 1} after" do
              # test body
            end
          end
        RUBY

        # The 3 responses are for the test class, none for the test declaration.
        assert_equal(3, response.size)
      end

      test "ignores tests with a non-string name argument" do
        response = generate_code_lens_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            test foo do
              # test body
            end
          end
        RUBY

        # The 3 responses are for the test class, none for the test declaration.
        assert_equal(3, response.size)
      end

      test "ignores test cases without a name" do
        response = generate_code_lens_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            test do
              # test body
            end
          end
        RUBY

        # The 3 responses are for the test class, none for the test declaration.
        assert_equal(3, response.size)
      end

      test "recognizes plain test cases" do
        response = generate_code_lens_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            def test_example
              # test body
            end
          end
        RUBY

        # The first 3 responses are for the test declaration.
        # The last 3 are for the test class.
        assert_equal(6, response.size)
        assert_match("Run", response[3].command.title)
        assert_equal("bin/rails test /fake.rb:2", response[3].command.arguments[2])
        assert_match("Run In Terminal", response[4].command.title)
        assert_match("Debug", response[5].command.title)
      end

      private

      def generate_code_lens_for_source(source)
        uri = URI("file:///fake.rb")
        store = RubyLsp::Store.new
        store.set(uri: uri, source: source, version: 1)

        response = RubyLsp::Executor.new(store, @message_queue).execute({
          method: "textDocument/codeLens",
          params: { textDocument: { uri: uri }, position: { line: 0, character: 0 } },
        })

        assert_nil(response.error)

        response.response
      end
    end
  end
end
