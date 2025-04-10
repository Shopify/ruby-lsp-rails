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
          assert_equal("SampleTest", test_class[:label])
          assert_equal(2, test_class[:children].length)

          test_labels = test_class[:children].map { |i| i[:label] }
          assert_includes(test_labels, "first test")
          assert_includes(test_labels, "second test")
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
          assert_equal("EmptyTest", test_class[:label])
          assert_equal(2, test_class[:children].length)

          test_labels = test_class[:children].map { |i| i[:label] }
          assert_includes(test_labels, "<empty test name>")
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
            test "test with spaces and punctuation!" do
              assert true
            end

            test "test with unicode: 你好" do
              assert true
            end
          end
        RUBY

        with_active_support_declarative_tests(source) do |items|
          assert_equal(1, items.length)
          test_class = items.first
          assert_equal("SpecialCharsTest", test_class[:label])
          assert_equal(2, test_class[:children].length)

          test_labels = test_class[:children].map { |i| i[:label] }
          assert_includes(test_labels, "test with spaces and punctuation!")
          assert_includes(test_labels, "test with unicode: 你好")
          assert_all_items_tagged_with(items, :rails)
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
