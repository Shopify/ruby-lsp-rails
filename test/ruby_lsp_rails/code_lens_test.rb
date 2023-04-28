# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class CodeLensTest < ActiveSupport::TestCase
      test "recognizes Rails active support test cases" do
        message_queue = Thread::Queue.new
        listener = CodeLens.new("", message_queue)

        test_name = "handles test case"

        RubyLsp::EventEmitter.new(listener).emit_for_target(Command(
          Ident("test"),
          Args([StringLiteral([TStringContent(test_name)], "")]),
          BodyStmt(SyntaxTree::VoidStmt, "", "", "", ""),
        ))

        assert_equal(test_name, T.must(T.must(listener.response).first).command.arguments[1])
      end
    end
  end
end
