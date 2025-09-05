# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class RailsTestStyleTest < ActiveSupport::TestCase
      test "discovers rails declarative tests" do
        source = <<~RUBY
          class SampleTest < ActiveSupport::TestCase
            test "first test" do
              assert true
            end

            test "second test" do
              assert true
            end
          end
        RUBY

        with_active_support_declarative_tests(source) do |items|
          assert_equal(1, items.length)
          test_class = items.first
          assert_equal("SampleTest", test_class[:id])
          assert_equal(2, test_class[:children].length)

          test_labels = test_class[:children].map { |i| i[:id] }
          assert_includes(test_labels, "SampleTest#test_first_test")
          assert_includes(test_labels, "SampleTest#test_second_test")
          assert_all_items_tagged_with(items, :rails)
        end
      end

      test "discovers rails test with empty test name" do
        source = <<~RUBY
          class EmptyTest < ActiveSupport::TestCase
            test "valid test" do
              assert true
            end

            test "" do
              assert true
            end
          end
        RUBY

        with_active_support_declarative_tests(source) do |items|
          assert_equal(1, items.length)
          test_class = items.first
          assert_equal("EmptyTest", test_class[:id])
          assert_equal(2, test_class[:children].length)

          test_labels = test_class[:children].map { |i| i[:id] }
          assert_includes(test_labels, "EmptyTest#test_<empty_test_name>")
          assert_all_items_tagged_with(items, :rails)
        end
      end

      test "handles nested namespaces" do
        source = <<~RUBY
          class EmptyTest < ActiveSupport::TestCase
            test "valid test" do
              assert true
            end

            module RandomModule
              test "not valid test" do
                assert false
              end
            end
          end
        RUBY

        with_active_support_declarative_tests(source) do |items|
          assert_equal(1, items.length)
          test_class = items.first
          assert_equal("EmptyTest", test_class[:label])
          assert_equal(1, test_class[:children].length)

          test_labels = test_class[:children].map { |i| i[:label] }
          refute_includes(test_labels, "not valid test")
        end
      end

      test "handles test methods defined with def" do
        source = <<~RUBY
          class SampleTest < ActiveSupport::TestCase
            test "first test" do
              assert true
            end

            def test_second_test
              assert true
            end
          end
        RUBY

        with_active_support_declarative_tests(source) do |items|
          assert_equal(1, items.length)
          test_class = items.first
          assert_equal("SampleTest", test_class[:label])
          assert_equal(2, test_class[:children].length)

          test_labels = test_class[:children].map { |i| i[:label] }
          assert_includes(test_labels, "test_second_test")
        end
      end

      test "handles tests with special characters in name" do
        source = <<~RUBY
          class SpecialCharsTest < ActiveSupport::TestCase
            test "spaces and punctuation!" do
              assert true
            end

            test "unicode: 你好" do
              assert true
            end
          end
        RUBY

        with_active_support_declarative_tests(source) do |items|
          assert_equal(1, items.length)
          test_class = items.first
          assert_equal("SpecialCharsTest", test_class[:id])
          assert_equal(2, test_class[:children].length)

          test_labels = test_class[:children].map { |i| i[:id] }
          assert_includes(test_labels, "SpecialCharsTest#test_spaces_and_punctuation!")
          assert_includes(test_labels, "SpecialCharsTest#test_unicode:_你好")
          assert_all_items_tagged_with(items, :rails)
        end
      end

      test "resolve test command entire files" do
        base_dir = Gem.win_platform? ? "D:/other/test" : "/other/test"
        test_paths = [
          File.join(base_dir, "fake_test.rb"),
          File.join(base_dir, "fake_test2.rb"),
        ]
        Dir.stubs(:glob).returns(test_paths)

        with_server do |server|
          sleep(0.1) while RubyLsp::Addon.addons.first.instance_variable_get(:@rails_runner_client).is_a?(NullClient)

          server.process_message({
            id: 1,
            method: "rubyLsp/resolveTestCommands",
            params: {
              items: [
                {
                  id: "file:///test/server_test.rb",
                  uri: "file:///test/server_test.rb",
                  label: "/test/server_test.rb",
                  tags: ["test_file", "framework:rails"],
                  children: [],
                },
                {
                  id: "file:///other/test",
                  uri: "file:///other/test",
                  label: "/other/test",
                  tags: ["test_dir", "framework:rails"],
                  children: [],
                },
              ],
            },
          })

          result = pop_result(server)
          response = result.response

          assert_equal(
            [
              "#{RailsTestStyle::BASE_COMMAND} /test/server_test.rb #{test_paths.join(" ")}",
            ],
            response[:commands],
          )
        end
      end

      test "resolve test command group test" do
        with_server do |server|
          sleep(0.1) while RubyLsp::Addon.addons.first.instance_variable_get(:@rails_runner_client).is_a?(NullClient)

          server.process_message({
            id: 1,
            method: "rubyLsp/resolveTestCommands",
            params: {
              items: [
                {
                  id: "GroupTest",
                  uri: "file:///test/group_test.rb",
                  label: "GroupTest",
                  range: {
                    start: { line: 0, character: 0 },
                    end: { line: 30, character: 3 },
                  },
                  tags: ["framework:rails", "test_group"],
                  children: [
                    {
                      id: "GroupTest#test_example",
                      uri: "file:///test/group_test.rb",
                      label: "test_example",
                      range: {
                        start: { line: 1, character: 2 },
                        end: { line: 10, character: 3 },
                      },
                      tags: ["framework:rails"],
                      children: [],
                    },
                  ],
                },
              ],
            },
          })

          result = pop_result(server)
          response = result.response

          assert_equal(
            [
              "#{RailsTestStyle::BASE_COMMAND} /test/group_test.rb --name \"/GroupTest(#|::)/\"",
              "#{RailsTestStyle::BASE_COMMAND} /test/group_test.rb:2",
            ],
            response[:commands],
          )
        end
      end

      test "resolve test escapes file paths in groups" do
        with_server do |server|
          sleep(0.1) while RubyLsp::Addon.addons.first.instance_variable_get(:@rails_runner_client).is_a?(NullClient)

          server.process_message({
            id: 1,
            method: "rubyLsp/resolveTestCommands",
            params: {
              items: [
                {
                  id: "GroupTest",
                  uri: "file:///test/group(v2)_test.rb",
                  label: "GroupTest",
                  range: {
                    start: { line: 0, character: 0 },
                    end: { line: 30, character: 3 },
                  },
                  tags: ["framework:rails", "test_group"],
                  children: [],
                },
              ],
            },
          })

          result = pop_result(server)
          response = result.response

          assert_equal(
            ["#{RailsTestStyle::BASE_COMMAND} /test/group\\(v2\\)_test.rb --name \"/GroupTest(#|::)/\""],
            response[:commands],
          )
        end
      end

      test "resolve test escapes single file paths" do
        with_server do |server|
          sleep(0.1) while RubyLsp::Addon.addons.first.instance_variable_get(:@rails_runner_client).is_a?(NullClient)

          server.process_message({
            id: 1,
            method: "rubyLsp/resolveTestCommands",
            params: {
              items: [
                {
                  id: "file:///test/example(v2)_test.rb",
                  uri: "file:///test/example(v2)_test.rb",
                  label: "/test/example(v2)_test.rb",
                  tags: ["framework:rails", "test_file"],
                  children: [],
                },
              ],
            },
          })

          result = pop_result(server)
          response = result.response

          assert_equal(
            ["#{RailsTestStyle::BASE_COMMAND} /test/example\\(v2\\)_test.rb"],
            response[:commands],
          )
        end
      end

      test "resolve test escapes file paths inside directories" do
        Dir.stubs(:glob).returns(["/test/example(v2)_test.rb"])

        with_server do |server|
          sleep(0.1) while RubyLsp::Addon.addons.first.instance_variable_get(:@rails_runner_client).is_a?(NullClient)

          server.process_message({
            id: 1,
            method: "rubyLsp/resolveTestCommands",
            params: {
              items: [
                {
                  id: "file:///test",
                  uri: "file:///test",
                  label: "/test",
                  tags: ["test_dir", "framework:rails"],
                  children: [],
                },
              ],
            },
          })

          result = pop_result(server)
          response = result.response

          assert_equal(
            ["#{RailsTestStyle::BASE_COMMAND} /test/example\\(v2\\)_test.rb"],
            response[:commands],
          )
        end
      end

      test "resolve test escapes file paths for specific examples" do
        with_server do |server|
          sleep(0.1) while RubyLsp::Addon.addons.first.instance_variable_get(:@rails_runner_client).is_a?(NullClient)

          server.process_message({
            id: 1,
            method: "rubyLsp/resolveTestCommands",
            params: {
              items: [
                {
                  id: "ExampleTest#test_something",
                  uri: "file:///test/example(v2)_test.rb",
                  label: "test something",
                  tags: ["framework:rails"],
                  range: {
                    start: { line: 10, character: 0 },
                    end: { line: 15, character: 3 },
                  },
                  children: [],
                },
              ],
            },
          })

          result = pop_result(server)
          response = result.response

          assert_equal(
            ["#{RailsTestStyle::BASE_COMMAND} /test/example\\(v2\\)_test.rb:11"],
            response[:commands],
          )
        end
      end

      test "tests with backslashes" do
        source = File.read(File.join(__dir__, "..", "fixtures", "test_with_escaped_quotes.rb"))

        with_active_support_declarative_tests(source) do |items|
          assert_equal(1, items.length)
          test_class = items.first
          assert_equal("SampleTest", test_class[:id])
          assert_equal(1, test_class[:children].length)

          assert_equal(["SampleTest#test_hello_\"oh_noes\""], test_class[:children].map { |i| i[:id] })
          assert_equal(["hello \"oh noes\""], test_class[:children].map { |i| i[:label] })
          assert_all_items_tagged_with(items, :rails)
        end
      end

      test "pushes code lenses to response builder" do
        source = <<~RUBY
          class SampleTest < ActiveSupport::TestCase
            test "first test" do
              assert true
            end

            test "second test" do
              assert true
            end
          end
        RUBY

        with_server(source, URI("/test/foo_test.rb")) do |server, uri|
          server.global_state.index.index_single(URI("/other_file.rb"), <<~RUBY)
            module Minitest
              class Test; end
            end

            module ActiveSupport
              module Testing
                module Declarative
                end
              end

              class TestCase < Minitest::Test
                extend Testing::Declarative
              end
            end
          RUBY

          server.global_state.stubs(:enabled_feature?).returns(true)

          server.process_message(id: 1, method: "textDocument/codeLens", params: {
            textDocument: { uri: uri },
          })

          result = pop_result(server)
          items = result.response
          assert_equal(9, items.length)
        end
      end

      test "nested test groups" do
        source = <<~RUBY
          class SampleTest < ActiveSupport::TestCase
            class InnerTest < ActiveSupport::TestCase
              test "first" do
              end
            end

            class AnotherGroupTest < ActiveSupport::TestCase
              test "second" do
              end
            end
          end
        RUBY

        with_active_support_declarative_tests(source) do |items|
          assert_equal(["SampleTest"], items.map { |i| i[:id] })
          assert_equal(
            ["SampleTest::InnerTest", "SampleTest::AnotherGroupTest"],
            items.dig(0, :children).map { |i| i[:id] },
          )
          assert_equal(
            ["SampleTest::InnerTest#test_first"],
            items.dig(0, :children, 0, :children).map { |i| i[:id] },
          )
          assert_equal(
            ["SampleTest::AnotherGroupTest#test_second"],
            items.dig(0, :children, 1, :children).map { |i| i[:id] },
          )
        end
      end

      test "namespaced test" do
        source = <<~RUBY
          module Foo
            class SampleTest < ActiveSupport::TestCase
              test "do something" do
              end
            end
          end
        RUBY

        with_active_support_declarative_tests(source) do |items|
          assert_equal(["Foo::SampleTest"], items.map { |i| i[:id] })
          assert_equal(
            ["Foo::SampleTest#test_do_something"],
            items.dig(0, :children).map { |i| i[:id] },
          )
        end
      end

      test "labels include only unformatted descriptions" do
        source = <<~RUBY
          class SampleTest < ActiveSupport::TestCase
            class InnerGroup < ActiveSupport::TestCase
              test "first test" do
                assert true
              end
            end
          end
        RUBY

        with_active_support_declarative_tests(source) do |items|
          assert_equal(["SampleTest"], items.map { |i| i[:label] })
          assert_equal(["InnerGroup"], items.dig(0, :children).map { |i| i[:label] })
          assert_equal(["first test"], items.dig(0, :children, 0, :children).map { |i| i[:label] })
        end
      end

      private

      def with_active_support_declarative_tests(source, file: "/fake.rb", &block)
        with_server(source, URI(file)) do |server, uri|
          server.global_state.index.index_single(uri, <<~RUBY)
            module Minitest
              class Test; end
            end

            module ActiveSupport
              module Testing
                module Declarative
                end
              end

              class TestCase < Minitest::Test
                extend Testing::Declarative
              end
            end
          RUBY

          server.process_message(id: 1, method: "rubyLsp/discoverTests", params: {
            textDocument: { uri: uri },
          })

          result = pop_result(server)
          items = result.response
          yield items
        end
      end

      def assert_all_items_tagged_with(items, tag)
        items.each do |item|
          assert_includes(item[:tags], "framework:#{tag}")
          children = item[:children]
          assert_all_items_tagged_with(children, tag) unless children.empty?
        end
      end
    end
  end
end
