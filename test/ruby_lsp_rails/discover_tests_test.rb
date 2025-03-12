# typed: true
# frozen_string_literal: true

require "test_helper"

# TODO: the tests pass individually but fail when all run together, find out why
# TODO: see code_lens_test.rb for possible things to handle

module RubyLsp
  class DiscoverTestsTest < ActiveSupport::TestCase # Minitest::Test
    include RubyLsp::TestHelper

    # def test_active_support_declarative
    test "active support declarative" do
      source = <<~RUBY
        class MyTest < ActiveSupport::TestCase
          test "hello world" do
          end
        end
      RUBY

      with_active_support_declarative_tests(source) do |items|
        assert_equal(1, items.size)
        assert_equal("hello world", items[0][:label])
        assert_equal([:active_support_declarative], items[0][:tags])
      end
    end

    test "ignores methods not named test" do
      source = <<~RUBY
        class MyTest < ActiveSupport::TestCase
          foo "something else" do
          end
        end
      RUBY

      with_active_support_declarative_tests(source) do |items|
        assert_empty(items)
      end
    end

    test "ignores tests without a block" do
      source = <<~RUBY
        class MyTest < ActiveSupport::TestCase
          test "something else"
        end
      RUBY

      with_active_support_declarative_tests(source) do |items|
        assert_empty(items)
      end
    end

    test "ignores tests with a non-string name argument" do
      source = <<~RUBY
        class MyTest < ActiveSupport::TestCase
          test foo do
          end
        end
      RUBY

      with_active_support_declarative_tests(source) do |items|
        assert_empty(items)
      end
    end

    test "ignores test cases without a name" do
      source = <<~RUBY
        class MyTest < ActiveSupport::TestCase
          test do
          end
        end
      RUBY

      with_active_support_declarative_tests(source) do |items|
        assert_empty(items)
      end
    end

    test "recognizes plain test cases" do
      source = <<~RUBY
        # module Minitest
        #   class Test; end
        # end

        # module ActiveSupport
        #   class TestCase < Minitest::Test
        #   end
        # end

        class MyTest < ActiveSupport::TestCase
          def test_foo
          end
        end
      RUBY

      with_active_support_declarative_tests(source) do |items|
        # binding.irb
        assert_equal(1, items.size)
      end
    end

    def with_active_support_declarative_tests(source, &block)
      puts "a1"
      with_server(source) do |server, uri|
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

        items = get_response(server)

        yield items
      end
    end

    def get_response(server)
      result = nil
      until result.is_a?(RubyLsp::Result)
        result = server.pop_response
        if result.is_a?(Error)
          flunk(result.message)
        end
      end

      result.response
    end
  end
end
