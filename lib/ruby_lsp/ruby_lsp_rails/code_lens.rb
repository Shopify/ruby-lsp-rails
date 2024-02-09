# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    # ![CodeLens demo](../../code_lens.gif)
    #
    # This feature adds several CodeLens features for Rails applications using Active Support test cases:
    # - Run tests in the VS Terminal
    # - Run tests in the VS Code Test Explorer
    # - Debug tests
    # - Run migrations in the VS Terminal
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
    # # Example:
    # ```ruby
    # Run in terminal
    # class AddFirstNameToUsers < ActiveRecord::Migration[7.1]
    #   # ...
    # end
    # ````
    #
    # The code lenses will be displayed above the class and above each test method.
    class CodeLens < ::RubyLsp::Listener
      extend T::Sig
      extend T::Generic

      ResponseType = type_member { { fixed: T::Array[::RubyLsp::Interface::CodeLens] } }
      MIGRATE_COMMAND = "bin/rails db:migrate"
      TEST_COMMAND = "bin/rails test"
      BASE_COMMAND = TEST_COMMAND # TODO: Deprecate?

      sig { override.returns(ResponseType) }
      attr_reader :_response

      sig { params(uri: URI::Generic, dispatcher: Prism::Dispatcher).void }
      def initialize(uri, dispatcher)
        @_response = T.let([], ResponseType)
        @path = T.let(uri.to_standardized_path, T.nilable(String))
        @group_id = T.let(1, Integer)
        @group_id_stack = T.let([], T::Array[Integer])

        dispatcher.register(self, :on_call_node_enter, :on_class_node_enter, :on_def_node_enter, :on_class_node_leave)

        super(dispatcher)
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        message_value = node.message
        return unless message_value == "test"

        arguments = node.arguments&.arguments
        return unless arguments&.any?

        first_argument = arguments.first

        content = case first_argument
        when Prism::InterpolatedStringNode
          parts = first_argument.parts

          if parts.all? { |part| part.is_a?(Prism::StringNode) }
            T.cast(parts, T::Array[Prism::StringNode]).map(&:content).join
          end
        when Prism::StringNode
          first_argument.content
        end

        return unless content && !content.empty?

        line_number = node.location.start_line
        command = "#{TEST_COMMAND} #{@path}:#{line_number}"
        add_test_code_lens(node, name: content, command: command, kind: :example)
      end

      # Although uncommon, Rails tests can be written with the classic "def test_name" syntax.
      sig { params(node: Prism::DefNode).void }
      def on_def_node_enter(node)
        method_name = node.name.to_s

        if method_name.start_with?("test_")
          line_number = node.location.start_line
          command = "#{TEST_COMMAND} #{@path}:#{line_number}"
          add_test_code_lens(node, name: method_name, command: command, kind: :example)
        end
      end

      sig { params(node: Prism::ClassNode).void }
      def on_class_node_enter(node)
        class_name = node.constant_path.slice
        superclass_name = node.superclass&.slice

        if class_name.end_with?("Test")
          command = "#{TEST_COMMAND} #{@path}"
          add_test_code_lens(node, name: class_name, command: command, kind: :group)
        end

        if superclass_name&.start_with?("ActiveRecord::Migration")
          command = "#{MIGRATE_COMMAND} VERSION=#{migration_version}"
          add_migrate_code_lens(node, name: class_name, command: command)
        end

        @group_id_stack.push(@group_id)
        @group_id += 1
      end

      sig { params(node: Prism::ClassNode).void }
      def on_class_node_leave(node)
        @group_id_stack.pop
      end

      private

      sig { returns(T.nilable(String)) }
      def migration_version
        File.basename(T.must(@path)).split("_").first
      end

      sig { params(node: Prism::Node, name: String, command: String).void }
      def add_migrate_code_lens(node, name:, command:)
        return unless @path

        arguments = [
          command,
          {
            start_line: node.location.start_line - 1,
            start_column: node.location.start_column,
            end_line: node.location.end_line - 1,
            end_column: node.location.end_column,
          },
        ]

        @_response << create_code_lens(
          node,
          title: "Run in terminal",
          command_name: "rubyLsp.runMigrationInTerminal",
          arguments: arguments,
          data: { type: "migrate" },
        )
      end

      sig { params(node: Prism::Node, name: String, command: String, kind: Symbol).void }
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

        grouping_data = { group_id: @group_id_stack.last, kind: kind }
        grouping_data[:id] = @group_id if kind == :group

        @_response << create_code_lens(
          node,
          title: "Run",
          command_name: "rubyLsp.runTest",
          arguments: arguments,
          data: { type: "test", **grouping_data },
        )

        @_response << create_code_lens(
          node,
          title: "Run In Terminal",
          command_name: "rubyLsp.runTestInTerminal",
          arguments: arguments,
          data: { type: "test_in_terminal", **grouping_data },
        )

        @_response << create_code_lens(
          node,
          title: "Debug",
          command_name: "rubyLsp.debugTest",
          arguments: arguments,
          data: { type: "debug", **grouping_data },
        )
      end
    end
  end
end
