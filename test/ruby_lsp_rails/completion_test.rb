# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class CompletionTest < ActiveSupport::TestCase
      test "on_call_node_enter returns when node_context has no call node" do
        response = generate_completions_for_source(<<~RUBY, { line: 1, character: 5 })
          # typed: false
          where
        RUBY

        assert_equal(0, response.size)
      end

      test "on_call_node_enter provides no suggestions when .where is called on a non ActiveRecord model" do
        response = generate_completions_for_source(<<~RUBY, { line: 1, character: 20 })
          # typed: false
          FakeClass.where(crea
        RUBY

        assert_equal(0, response.size)
      end

      test "on_call_node_enter provides completions when AR model column name is typed partially" do
        response = generate_completions_for_source(<<~RUBY, { line: 1, character: 17 })
          # typed: false
          User.where(first_
        RUBY

        assert_equal(1, response.size)
        assert_equal("first_name", response[0].label)
        assert_equal("first_name", response[0].filter_text)
        assert_equal(11, response[0].text_edit.range.start.character)
        assert_equal(1, response[0].text_edit.range.start.line)
        assert_equal(17, response[0].text_edit.range.end.character)
        assert_equal(1, response[0].text_edit.range.end.line)
      end

      test "on_call_node_enter does not provide column name suggestion if column is already a key in the .where call" do
        response = generate_completions_for_source(<<~RUBY, { line: 1, character: 37 })
          # typed: false
          User.where(id:, first_name:, first_na
        RUBY

        assert_equal(0, response.size)
      end

      test "on_call_node_enter doesn't provide completions when typing an argument's value within a .where call" do
        response = generate_completions_for_source(<<~RUBY, { line: 1, character: 20 })
          # typed: false
          User.where(id: creat
        RUBY
        assert_equal(0, response.size)
      end

      test "on_call_node_enter provides fixture name completions when typing partial fixture name" do
        response = generate_completions_for_source(<<~RUBY, { line: 1, character: 9 })
          # typed: false
          users(:b
        RUBY

        assert_equal(1, response.size)
        assert_equal("bob", response[0].label)
        assert_equal("bob", response[0].filter_text)
        assert_equal("users fixture", response[0].label_details.description)
        assert_equal(":bob", response[0].text_edit.new_text)
      end

      test "on_call_node_enter provides all fixture name completions when no prefix" do
        response = generate_completions_for_source(<<~RUBY, { line: 1, character: 8 })
          # typed: false
          users(:
        RUBY

        assert_equal(3, response.size)
        fixture_names = response.map(&:label).sort
        assert_equal(["alice", "bob", "joe"], fixture_names)
        response.each do |item|
          assert_equal("users fixture", item.label_details.description)
        end
      end

      test "on_call_node_enter provides fixture completions for posts" do
        response = generate_completions_for_source(<<~RUBY, { line: 1, character: 8 })
          # typed: false
          posts(:
        RUBY

        assert_equal(2, response.size)
        fixture_names = response.map(&:label).sort
        assert_equal(["first_post", "second_post"], fixture_names)
      end

      test "on_call_node_enter does not provide fixture completions when call has a receiver" do
        response = generate_completions_for_source(<<~RUBY, { line: 1, character: 17 })
          # typed: false
          SomeClass.users(:
        RUBY

        assert_equal(0, response.size)
      end

      test "on_call_node_enter does not provide fixture completions when call has no arguments" do
        response = generate_completions_for_source(<<~RUBY, { line: 1, character: 5 })
          # typed: false
          users
        RUBY

        assert_equal(0, response.size)
      end

      private

      def generate_completions_for_source(source, position)
        with_server(source) do |server, uri|
          sleep(0.1) while RubyLsp::Addon.addons.first.instance_variable_get(:@rails_runner_client).is_a?(NullClient)

          server.process_message(
            id: 1,
            method: "textDocument/completion",
            params: { textDocument: { uri: uri }, position: position },
          )

          result = pop_result(server)
          result.response
        end
      end
    end
  end
end
