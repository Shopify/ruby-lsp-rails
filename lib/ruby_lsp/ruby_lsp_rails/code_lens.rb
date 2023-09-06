# typed: strict
# frozen_string_literal: true

require_relative "support/active_support_test_helper"

module RubyLsp
  module Rails
    # ![CodeLens demo](../../code_lens.gif)
    #
    # This feature adds several CodeLens features for Rails applications using Active Support test cases:
    # - Run tests in the VS Terminal
    # - Run tests in the VS Code Test Explorer
    # - Debug tests
    #
    # The
    # [code lens](https://microsoft.github.io/language-server-protocol/specification#textDocument_codeLens)
    # request informs the editor of runnable commands such as tests
    #
    # # Example:
    #
    # For the following code, Code Lenses will be added above the class definition above each test method.
    #
    # ```ruby
    # Run
    # class HelloTest < ActiveSupport::TestCase # <- Will show code lenses above for running or debugging the whole test
    #   test "outputs hello" do # <- Will show code lenses above for running or debugging this test
    #     # ...
    #   end
    #
    #   test "outputs goodbye" do # <- Will show code lenses above for running or debugging this test
    #     # ...
    #   end
    # end
    # ````
    #
    # The code lenses will be displayed above the class and above each test method.
    class CodeLens < ::RubyLsp::Listener
      extend T::Sig
      extend T::Generic

      include ActiveSupportTestHelper

      ResponseType = type_member { { fixed: T::Array[::RubyLsp::Interface::CodeLens] } }
      BASE_COMMAND = "bin/rails test"

      sig { override.returns(ResponseType) }
      attr_reader :response

      sig { params(uri: URI::Generic, emitter: EventEmitter, message_queue: Thread::Queue).void }
      def initialize(uri, emitter, message_queue)
        @response = T.let([], ResponseType)
        @path = T.let(uri.to_standardized_path, T.nilable(String))
        emitter.register(self, :on_command, :on_class, :on_def)

        super(emitter, message_queue)
      end

      sig { params(node: SyntaxTree::Command).void }
      def on_command(node)
        test_name = active_support_test_name(node)

        return unless test_name

        line_number = node.location.start_line
        command = "#{BASE_COMMAND} #{@path}:#{line_number}"
        add_test_code_lens(node, name: test_name, command: command, kind: :example)
      end

      # Although uncommon, Rails tests can be written with the classic "def test_name" syntax.
      sig { params(node: SyntaxTree::DefNode).void }
      def on_def(node)
        method_name = node.name.value
        if method_name.start_with?("test_")
          line_number = node.location.start_line
          command = "#{BASE_COMMAND} #{@path}:#{line_number}"
          add_test_code_lens(node, name: method_name, command: command, kind: :example)
        end
      end

      sig { params(node: SyntaxTree::ClassDeclaration).void }
      def on_class(node)
        class_name = node.constant.constant.value
        if class_name.end_with?("Test")
          command = "#{BASE_COMMAND} #{@path}"
          add_test_code_lens(node, name: class_name, command: command, kind: :group)
        end
      end

      private

      sig { params(node: SyntaxTree::Node, name: String, command: String, kind: Symbol).void }
      def add_test_code_lens(node, name:, command:, kind:)
        return unless @path

        arguments = [
          @path,
          name,
          command,
          {
            start_line: node.location.start_line - 1,
            start_column: node.location.start_column,
            end_line: node.location.end_line - 1,
            end_column: node.location.end_column,
          },
        ]

        @response << create_code_lens(
          node,
          title: "Run",
          command_name: "rubyLsp.runTest",
          arguments: arguments,
          data: { type: "test", kind: kind },
        )

        @response << create_code_lens(
          node,
          title: "Run In Terminal",
          command_name: "rubyLsp.runTestInTerminal",
          arguments: arguments,
          data: { type: "test_in_terminal", kind: kind },
        )

        @response << create_code_lens(
          node,
          title: "Debug",
          command_name: "rubyLsp.debugTest",
          arguments: arguments,
          data: { type: "debug", kind: kind },
        )
      end
    end
  end
end
