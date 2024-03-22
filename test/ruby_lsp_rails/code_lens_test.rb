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

      test "recognizes Rails Active Support test cases using minitest/spec" do
        response = generate_code_lens_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            it "an example" do
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

      test "assigns the correct hierarchy to test structure" do
        response = generate_code_lens_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            test "an example" do
              # test body
            end

            class NestedTest < ActiveSupport::TestCase
              test "other" do
                # other test body
              end
            end

            test "back to the same level" do
              # test body
            end
          end
        RUBY

        data = response.map(&:data)

        # Code lenses for `Test`
        explorer, terminal, debug = data.shift(3)
        assert_nil(explorer[:group_id])
        assert_nil(terminal[:group_id])
        assert_nil(debug[:group_id])
        assert_equal(1, explorer[:id])
        assert_equal(1, terminal[:id])
        assert_equal(1, debug[:id])

        # Code lenses for `an example`
        explorer, terminal, debug = data.shift(3)
        assert_equal(1, explorer[:group_id])
        assert_equal(1, terminal[:group_id])
        assert_equal(1, debug[:group_id])

        # Code lenses for `NestedTest`
        explorer, terminal, debug = data.shift(3)
        assert_equal(1, explorer[:group_id])
        assert_equal(1, terminal[:group_id])
        assert_equal(1, debug[:group_id])
        assert_equal(2, explorer[:id])
        assert_equal(2, terminal[:id])
        assert_equal(2, debug[:id])

        # Code lenses for `other`
        explorer, terminal, debug = data.shift(3)
        assert_equal(2, explorer[:group_id])
        assert_equal(2, terminal[:group_id])
        assert_equal(2, debug[:group_id])

        # Code lenses for `back to the same level`
        explorer, terminal, debug = data.shift(3)
        assert_equal(1, explorer[:group_id])
        assert_equal(1, terminal[:group_id])
        assert_equal(1, debug[:group_id])

        assert_empty(data)
      end

      private

      def generate_code_lens_for_source(source)
        with_server(source) do |server, uri|
          server.process_message(
            id: 1,
            method: "textDocument/codeLens",
            params: { textDocument: { uri: uri }, position: { line: 0, character: 0 } },
          )

          result = server.pop_response

          assert_instance_of(RubyLsp::Result, result)
          result.response
        end
      end
    end
  end
end
