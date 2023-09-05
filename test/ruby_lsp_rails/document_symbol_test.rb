# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class DocumentSymbolTest < ActiveSupport::TestCase
      setup do
        @message_queue = Thread::Queue.new
        @store = RubyLsp::Store.new
        @uri = URI("file:///fake.rb")
      end

      def teardown
        T.must(@message_queue).close
      end

      test "recognizes Rails Active Support test cases" do
        @store.set(uri: @uri, source: <<~RUBY, version: 1)
          class FooTest < ActiveSupport::TestCase
            test "a test case" do
              # test body
            end
          end
        RUBY

        response = RubyLsp::Executor.new(@store, @message_queue).execute({
          method: "textDocument/documentSymbol",
          params: { textDocument: { uri: @uri }, position: { line: 0, character: 0 } },
        }).response

        # The first symbol of FooTest is from ruby-lsp itself.
        assert_equal(2, response.size)

        assert_equal("FooTest", response[1].name)
        assert_equal(LanguageServer::Protocol::Constant::SymbolKind::CLASS, response[1].kind)

        child_symbols = response[1].children
        assert_equal(1, child_symbols.size)
        assert_equal("a test case", child_symbols.first.name)
        assert_equal(LanguageServer::Protocol::Constant::SymbolKind::METHOD, child_symbols.first.kind)
      end

      test "ignores unnamed tests (empty string)" do
        @store.set(uri: @uri, source: <<~RUBY, version: 1)
          class Test < ActiveSupport::TestCase
            test "" do
              # test body
            end
          end
        RUBY

        response = RubyLsp::Executor.new(@store, @message_queue).execute({
          method: "textDocument/documentSymbol",
          params: { textDocument: { uri: @uri }, position: { line: 0, character: 0 } },
        }).response

        # Only the test class is returned.
        # The first symbol of FooTest is from ruby-lsp itself.
        assert_equal(2, response.size)
      end

      test "ignores tests with interpolation in their names" do
        @store.set(uri: @uri, source: <<~'RUBY', version: 1)
          class Test < ActiveSupport::TestCase
            test "before #{1 + 1} after" do
              # test body
            end
          end
        RUBY

        response = RubyLsp::Executor.new(@store, @message_queue).execute({
          method: "textDocument/documentSymbol",
          params: { textDocument: { uri: @uri }, position: { line: 0, character: 0 } },
        }).response

        # Only the test class is returned.
        # The first symbol of FooTest is from ruby-lsp itself.
        assert_equal(2, response.size)
      end

      test "ignores test cases without a name" do
        @store.set(uri: @uri, source: <<~RUBY, version: 1)
          class Test < ActiveSupport::TestCase
            test do
              # test body
            end
          end
        RUBY

        response = RubyLsp::Executor.new(@store, @message_queue).execute({
          method: "textDocument/documentSymbol",
          params: { textDocument: { uri: @uri }, position: { line: 0, character: 0 } },
        }).response

        # Only the test class is returned.
        # The first symbol of FooTest is from ruby-lsp itself.
        assert_equal(2, response.size)
      end
    end
  end
end
