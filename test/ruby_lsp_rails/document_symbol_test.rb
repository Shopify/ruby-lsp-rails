# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class DocumentSymbolTest < ActiveSupport::TestCase
      setup do
        @message_queue = Thread::Queue.new
      end

      def teardown
        T.must(@message_queue).close
      end

      test "recognizes Rails Active Support test cases" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            test "an example" do
              # test body
            end
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("Test", response[0].name)
        assert_equal(1, response[0].children.size)
        assert_equal("an example", response[0].children[0].name)
      end

      test "recognizes Rails Active Support test cases using minitest/spec" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            it "an example" do
              # test body
            end
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("Test", response[0].name)
        assert_equal(1, response[0].children.size)
        assert_equal("an example", response[0].children[0].name)
      end

      test "recognizes multiline escaped strings" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            test "an example" \
              "multiline" do
              # test body
            end
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("Test", response[0].name)
        assert_equal(1, response[0].children.size)
        assert_equal("an examplemultiline", response[0].children[0].name)
      end

      test "ignores unnamed tests (empty string)" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            test "" do
              # test body
            end
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("Test", response[0].name)
        assert_empty(response[0].children)
      end

      test "ignores tests with interpolation in their names" do
        # Note that we need to quote the heredoc RUBY marker to prevent interpolation when defining the test.
        response = generate_document_symbols_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            test "before \#{1 + 1} after" do
              # test body
            end
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("Test", response[0].name)
        assert_empty(response[0].children)
      end

      test "ignores tests with a non-string name argument" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            test foo do
              # test body
            end
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("Test", response[0].name)
        assert_empty(response[0].children)
      end

      test "ignores test cases without a name" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            test do
              # test body
            end
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("Test", response[0].name)
        assert_empty(response[0].children)
      end

      test "recognizes plain test cases" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class Test < ActiveSupport::TestCase
            def test_example
              # test body
            end
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("Test", response[0].name)
        assert_equal(1, response[0].children.size)
        assert_equal("test_example", response[0].children[0].name)
      end

      test "assigns the correct hierarchy to test structure" do
        response = generate_document_symbols_for_source(<<~RUBY)
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

        assert_equal(1, response.size)
        assert_equal("Test", response[0].name)
        assert_equal(3, response[0].children.size)
        assert_equal("an example", response[0].children[0].name)
        nexted_test = response[0].children[1]
        assert_equal("NestedTest", nexted_test.name)
        assert_equal(1, nexted_test.children.size)
        assert_equal("other", nexted_test.children[0].name)

        assert_equal("back to the same level", response[0].children[2].name)
      end

      test "correctly handles model callbacks with multiple string arguments" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class FooModel < ApplicationRecord
            before_save "foo_method", "bar_method", on: :update
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("FooModel", response[0].name)
        assert_equal(2, response[0].children.size)
        assert_equal("before_save :foo_method", response[0].children[0].name)
        assert_equal("before_save :bar_method", response[0].children[1].name)
      end

      test "correctly handles controller callback with block" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class FooController < ApplicationController
            before_action do
              # block body
            end
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("FooController", response[0].name)
        assert_equal(1, response[0].children.size)
        assert_equal("before_action <anonymous>", response[0].children[0].name)
      end

      test "correctly handles job callback with symbol argument" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class FooJob < ApplicationJob
            before_perform :foo_method
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("FooJob", response[0].name)
        assert_equal(1, response[0].children.size)
        assert_equal("before_perform :foo_method", response[0].children[0].name)
      end

      test "correctly handles model callback with lambda argument" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class FooModel < ApplicationRecord
            before_save -> () {}
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("FooModel", response[0].name)
        assert_equal(1, response[0].children.size)
        assert_equal("before_save <anonymous>", response[0].children[0].name)
      end

      test "correctly handles job callbacks with method call argument" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class FooJob < ApplicationJob
            before_perform FooClass.new(foo_arg)
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("FooJob", response[0].name)
        assert_equal(1, response[0].children.size)
        assert_equal("before_perform FooClass", response[0].children[0].name)
      end

      test "correctly handles controller callbacks with constant argument" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class FooController < ApplicationController
            before_action FooClass
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("FooController", response[0].name)
        assert_equal(1, response[0].children.size)
        assert_equal("before_action FooClass", response[0].children[0].name)
      end

      test "correctly handles model callbacks with namespaced constant argument" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class FooModel < ApplicationRecord
            before_save Foo::BarClass
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("FooModel", response[0].name)
        assert_equal(1, response[0].children.size)
        assert_equal("before_save Foo::BarClass", response[0].children[0].name)
      end

      test "correctly handles job callbacks with all argument types" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class FooJob < ApplicationJob
            before_perform "foo_arg", :bar_arg, -> () {}, Foo::BazClass.new("blah"), FooClass, Foo::BarClass
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("FooJob", response[0].name)
        assert_equal(6, response[0].children.size)
        assert_equal("before_perform :foo_arg", response[0].children[0].name)
        assert_equal("before_perform :bar_arg", response[0].children[1].name)
        assert_equal("before_perform <anonymous>", response[0].children[2].name)
        assert_equal("before_perform Foo::BazClass", response[0].children[3].name)
        assert_equal("before_perform FooClass", response[0].children[4].name)
        assert_equal("before_perform Foo::BarClass", response[0].children[5].name)
      end

      test "ignore unrecognized callback" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class FooJob < ApplicationJob
            unrecognized_callback :foo_method
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("FooJob", response[0].name)
        assert_empty(response[0].children)
      end

      test "correctly handles validate method with all argument types" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class FooModel < ApplicationRecord
            validate "foo_arg", :bar_arg, -> () {}, Foo::BazClass.new("blah"), FooClass, Foo::BarClass
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("FooModel", response[0].name)
        assert_equal(6, response[0].children.size)
        assert_equal("validate :foo_arg", response[0].children[0].name)
        assert_equal("validate :bar_arg", response[0].children[1].name)
        assert_equal("validate <anonymous>", response[0].children[2].name)
        assert_equal("validate Foo::BazClass", response[0].children[3].name)
        assert_equal("validate FooClass", response[0].children[4].name)
        assert_equal("validate Foo::BarClass", response[0].children[5].name)
      end

      test "correctly handles validates method with string and symbol argument types" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class FooModel < ApplicationRecord
            validates "foo_arg", :bar_arg
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("FooModel", response[0].name)
        assert_equal(2, response[0].children.size)
        assert_equal("validates :foo_arg", response[0].children[0].name)
        assert_equal("validates :bar_arg", response[0].children[1].name)
      end

      test "correctly handles validates_each method with string and symbol argument types" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class FooModel < ApplicationRecord
            validates_each "foo_arg", :bar_arg do
              puts "Foo"
            end
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("FooModel", response[0].name)
        assert_equal(2, response[0].children.size)
        assert_equal("validates_each :foo_arg", response[0].children[0].name)
        assert_equal("validates_each :bar_arg", response[0].children[1].name)
      end

      test "correctly handles validates_with method with constant and namespaced constant argument types" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class FooModel < ApplicationRecord
            validates_with FooClass, Foo::BarClass
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("FooModel", response[0].name)
        assert_equal(2, response[0].children.size)
        assert_equal("validates_with FooClass", response[0].children[0].name)
        assert_equal("validates_with Foo::BarClass", response[0].children[1].name)
      end

      test "correctly handles association callbacks with string and symbol argument types" do
        response = generate_document_symbols_for_source(<<~RUBY)
          class FooModel < ApplicationRecord
            belongs_to :foo
            belongs_to "baz"
          end
        RUBY

        assert_equal(1, response.size)
        assert_equal("FooModel", response[0].name)
        assert_equal(2, response[0].children.size)
        assert_equal("belongs_to :foo", response[0].children[0].name)
        assert_equal("belongs_to :baz", response[0].children[1].name)
      end

      private

      def generate_document_symbols_for_source(source)
        with_server(source) do |server, uri|
          server.process_message(
            id: 1,
            method: "textDocument/documentSymbol",
            params: { textDocument: { uri: uri }, position: { line: 0, character: 0 } },
          )

          server.pop_response.response
        end
      end
    end
  end
end
