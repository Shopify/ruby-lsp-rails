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

      test "on_call_node_enter provides completion for migration files" do
        source = <<~RUBY
          # typed: false
          class FooBar < ActiveRecord::Migration[8.0]
            def change
              create
            end
          end
        RUBY
        position = { line: 3, character: 10 }
        uri = Kernel.URI("file://#{dummy_root}/db/migrate/123456789_foo_bar.rb")

        response = with_ready_server(source, uri) do |server|
          index_gem(server.global_state.index, "activerecord")
          text_document_completion(server, uri, position)
        end

        assert_includes response.map(&:label), "create_table"
      end

      private

      def generate_completions_for_source(source, position, uri = Kernel.URI("file:///fake.rb"))
        with_ready_server(source, uri) do |server, uri|
          text_document_completion(server, uri, position)
        end
      end

      def with_ready_server(source, uri)
        with_server(source, uri) do |server|
          sleep(0.1) while RubyLsp::Addon.addons.first.instance_variable_get(:@rails_runner_client).is_a?(NullClient)

          yield server
        end
      end

      def text_document_completion(server, uri, position)
        server.process_message(
          id: 1,
          method: "textDocument/completion",
          params: { textDocument: { uri: uri }, position: position },
        )

        result = pop_result(server)
        result.response
      end

      def index_gem(index, gem_name)
        spec = Gem::Specification.find_by_name(gem_name)
        spec.require_paths.each do |require_path|
          load_path_entry = File.join(spec.full_gem_path, require_path)
          Dir.glob(File.join(load_path_entry, "**", "*.rb")).map! do |path|
            uri = URI::Generic.from_path(path: path, load_path_entry: load_path_entry)
            index.index_file(uri)
          end
        end
      end
    end
  end
end
