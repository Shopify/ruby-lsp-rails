# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class DefinitionTest < ActiveSupport::TestCase
      test "recognizes model callback with multiple symbol arguments" do
        response = generate_definitions_for_source(<<~RUBY, { line: 3, character: 10 })
          # typed: false

          class TestModel
            before_create :foo, :baz

            def foo; end
            def baz; end
          end
        RUBY

        assert_equal(2, response.size)

        assert_equal("file:///fake.rb", response[0].uri)
        assert_equal(5, response[0].range.start.line)
        assert_equal(2, response[0].range.start.character)
        assert_equal(5, response[0].range.end.line)
        assert_equal(14, response[0].range.end.character)

        assert_equal("file:///fake.rb", response[1].uri)
        assert_equal(6, response[1].range.start.line)
        assert_equal(2, response[1].range.start.character)
        assert_equal(6, response[1].range.end.line)
        assert_equal(14, response[1].range.end.character)
      end

      test "recognizes controller callback with string argument" do
        response = generate_definitions_for_source(<<~RUBY, { line: 3, character: 10 })
          # typed: false

          class TestController
            before_action "foo"

            def foo; end
          end
        RUBY

        assert_equal(1, response.size)

        assert_equal("file:///fake.rb", response[0].uri)
        assert_equal(5, response[0].range.start.line)
        assert_equal(2, response[0].range.start.character)
        assert_equal(5, response[0].range.end.line)
        assert_equal(14, response[0].range.end.character)
      end

      test "recognizes job callback with string and symbol arguments" do
        response = generate_definitions_for_source(<<~RUBY, { line: 3, character: 10 })
          # typed: false

          class TestJob
            before_perform :foo, "baz"

            def foo; end
            def baz; end
          end
        RUBY

        assert_equal(2, response.size)

        assert_equal("file:///fake.rb", response[0].uri)
        assert_equal(5, response[0].range.start.line)
        assert_equal(2, response[0].range.start.character)
        assert_equal(5, response[0].range.end.line)
        assert_equal(14, response[0].range.end.character)

        assert_equal("file:///fake.rb", response[1].uri)
        assert_equal(6, response[1].range.start.line)
        assert_equal(2, response[1].range.start.character)
        assert_equal(6, response[1].range.end.line)
        assert_equal(14, response[1].range.end.character)
      end

      test "provides the definition of a route" do
        response = generate_definitions_for_source(<<~RUBY, { line: 0, character: 0 })
          users_path
        RUBY

        assert_equal(1, response.size)
        dummy_root = File.expand_path("../dummy", __dir__)
        assert_equal("file://#{dummy_root}/config/routes.rb", response[0].uri)
        assert_equal(3, response[0].range.start.line)
        assert_equal(3, response[0].range.end.line)
      end

      test "handles incomplete routes" do
        response = generate_definitions_for_source(<<~RUBY, { line: 0, character: 0 })
          _path
        RUBY

        assert_empty(response)
      end

      test "provides the definition of a custom route" do
        response = generate_definitions_for_source(<<~RUBY, { line: 0, character: 0 })
          archive_users_path
        RUBY

        assert_equal(1, response.size)
        dummy_root = File.expand_path("../dummy", __dir__)
        assert_equal("file://#{dummy_root}/config/routes.rb", response[0].uri)
        assert_equal(4, response[0].range.start.line)
        assert_equal(4, response[0].range.end.line)
      end

      test "ignored non-existing routes" do
        response = generate_definitions_for_source(<<~RUBY, { line: 0, character: 0 })
          invalid_path
        RUBY

        assert_empty(response)
      end

      private

      def generate_definitions_for_source(source, position)
        with_server(source) do |server, uri|
          server.process_message(
            id: 1,
            method: "textDocument/definition",
            params: { textDocument: { uri: uri }, position: position },
          )

          server.pop_response.response
        end
      end
    end
  end
end
