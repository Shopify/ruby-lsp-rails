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
        response = generate_completions_for_source(<<~RUBY, { line: 3, character: 15 })
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

      private

      def generate_completions_for_source(source, position)
        with_server(source, stub_no_typechecker: true) do |server, uri|
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
