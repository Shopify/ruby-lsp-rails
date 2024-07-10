# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class CodeLensTest < ActiveSupport::TestCase
      setup do
        GlobalState.any_instance.stubs(:test_library).returns("rails")
        @ruby = Gem.win_platform? ? "ruby.exe" : "ruby"
      end

      test "does not create code lenses if rails is not the test library" do
        RubyLsp::GlobalState.any_instance.stubs(:test_library).returns("rspec")
        response = generate_code_lens_for_source(<<~RUBY)
          RSpec.describe "an example" do
            it "an example" do
              # test body
            end
          end
        RUBY

        assert_empty(response)
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
        assert_match(%r{(ruby )?bin/rails test /fake\.rb:2}, response[3].command.arguments[2])
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
        assert_match(%r{(ruby )?bin/rails test /fake\.rb:2}, response[3].command.arguments[2])
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
        assert_match(%r{(ruby )?bin/rails test /fake\.rb:2}, response[3].command.arguments[2])
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
        assert_match(%r{(ruby )?bin/rails test /fake\.rb:2}, response[3].command.arguments[2])
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

      test "recognizes nested class structure correctly" do
        response = generate_code_lens_for_source(<<~RUBY)
          module Foo
            class Bar
              class Test < ActiveSupport::TestCase
                test "an example" do
                  # test body
                end
              end
            end

            class AnotherTest < ActiveSupport::TestCase
              test "an example" do
                # test body
              end
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

        # Code lenses for `AnotherTest`
        explorer, terminal, debug = data.shift(3)
        assert_nil(explorer[:group_id])
        assert_nil(terminal[:group_id])
        assert_nil(debug[:group_id])
        assert_equal(2, explorer[:id])
        assert_equal(2, terminal[:id])
        assert_equal(2, debug[:id])

        # Code lenses for `an example`
        explorer, terminal, debug = data.shift(3)
        assert_equal(2, explorer[:group_id])
        assert_equal(2, terminal[:group_id])
        assert_equal(2, debug[:group_id])

        assert_empty(data)
      end

      test "prefixes the binstub call with `ruby` on Windows" do
        Gem.stubs(:win_platform?).returns(true)
        response = generate_code_lens_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
          end
        RUBY

        assert_match("#{ruby} bin/rails test /fake.rb", response[0].command.arguments[2])
      end

      test "recognizes migrations" do
        response = generate_code_lens_for_source(<<~RUBY, file: "file://db/migrate/123456_add_first_name_to_users.rb")
          class AddFirstNameToUsers < ActiveRecord::Migration[7.1]
            def change
              add_column(:users, :first_name, :string)
            end
          end
        RUBY

        assert_equal(1, response.size)
        assert_match("Run", response[0].command.title)
        assert_match("#{ruby} bin/rails db:migrate VERSION=123456", response[0].command.arguments[0])
      end

      test "recognizes controller actions" do
        response = generate_code_lens_for_source(<<~RUBY)
          class UsersController < ApplicationController
            def index
            end
          end
        RUBY
        path, line = response[0].command.arguments.first

        assert_equal(1, response.size)
        assert_match("GET /users(.:format)", response[0].command.title)
        assert_equal("4", line)
        assert_match("config/routes.rb", path)
      end

      test "doesn't break when analyzing a file without a class" do
        response = generate_code_lens_for_source(<<~RUBY)
          def index
          end
        RUBY

        assert_empty(response)
      end

      private

      attr_reader :ruby

      def generate_code_lens_for_source(source, file: "/fake.rb")
        with_server(source, URI(file)) do |server, uri|
          sleep(0.1) while RubyLsp::Addon.addons.first.instance_variable_get(:@client).is_a?(NullClient)

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
