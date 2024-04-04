# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class CompletionTest < ActiveSupport::TestCase
      setup do
        @message_queue = Thread::Queue.new
      end

      def teardown
        T.must(@message_queue).close
      end

      test "..." do
        uri = URI::Generic.from_path(path: "/users_controller.rb")
        response = generate_completions_for_source(<<~RUBY, { line: 3, character: 15 }, uri)
          # typed: false

          def foo
            redirect_to u
          end
        RUBY
        assert_equal(
          [
            "edit_user_path",
            "edit_user_url",
            "new_user_path",
            "new_user_url",
            "user_path",
            "user_url",
            "users_path",
            "users_url",
          ],
          response.map(&:label).sort,
        )
      end

      test "does not suggest completions for other kinds of files" do
        uri = URI::Generic.from_path(path: "/other.rb")
        response = generate_completions_for_source(<<~RUBY, { line: 3, character: 15 }, uri)
          # typed: false

          def foo
            redirect_to u
          end
        RUBY

        assert_empty(response)
      end

      private

      def generate_completions_for_source(source, position, my_uri)
        with_server(source, my_uri, stub_no_typechecker: true) do |server, uri|
          # We need to wait for Rails to boot
          while RubyLsp::Addon.addons.first.instance_variable_get(:@client).instance_of?(RubyLsp::Rails::NullClient)
            Thread.pass
          end

          server.process_message(
            id: 1,
            method: "textDocument/completion",
            params: { textDocument: { uri: uri }, position: position },
          )

          server.pop_response.response
        end
      end
    end
  end
end
