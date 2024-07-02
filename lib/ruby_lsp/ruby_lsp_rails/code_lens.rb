# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    # ![CodeLens demo](../../code_lens.gif)
    #
    # This feature adds several CodeLens features for Rails applications using Active Support test cases:
    #
    # - Run tests in the VS Terminal
    # - Run tests in the VS Code Test Explorer
    # - Debug tests
    # - Run migrations in the VS Terminal
    #
    # The
    # [code lens](https://microsoft.github.io/language-server-protocol/specification#textDocument_codeLens)
    # request informs the editor of runnable commands such as tests.
    # It's available for tests which inherit from `ActiveSupport::TestCase` or one of its descendants, such as
    # `ActionDispatch::IntegrationTest`.
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
    # Run
    # class AddFirstNameToUsers < ActiveRecord::Migration[7.1]
    #   # ...
    # end
    # ````
    #
    # The code lenses will be displayed above the class and above each test method.
    #
    # Note: When using the Test Explorer view, if your code contains a statement to pause execution (e.g. `debugger`) it
    # will cause the test runner to hang.
    class CodeLens
      extend T::Sig
      include Requests::Support::Common
      include ActiveSupportTestCaseHelper

      sig do
        params(
          response_builder:  ResponseBuilders::CollectionResponseBuilder[Interface::CodeLens],
          uri: URI::Generic,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def initialize(response_builder, uri, dispatcher)
        @response_builder = response_builder
        @path = T.let(uri.to_standardized_path, T.nilable(String))
        @group_id = T.let(1, Integer)
        @group_id_stack = T.let([], T::Array[Integer])

        dispatcher.register(self, :on_call_node_enter, :on_class_node_enter, :on_def_node_enter, :on_class_node_leave)
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        content = extract_test_case_name(node)

        return unless content

        line_number = node.location.start_line
        command = "#{test_command} #{@path}:#{line_number}"
        add_test_code_lens(node, name: content, command: command, kind: :example)
      end

      # Although uncommon, Rails tests can be written with the classic "def test_name" syntax.
      sig { params(node: Prism::DefNode).void }
      def on_def_node_enter(node)
        method_name = node.name.to_s

        if method_name.start_with?("test_")
          line_number = node.location.start_line
          command = "#{test_command} #{@path}:#{line_number}"
          add_test_code_lens(node, name: method_name, command: command, kind: :example)
        end
      end

      sig { params(node: Prism::ClassNode).void }
      def on_class_node_enter(node)
        class_name = node.constant_path.slice
        superclass_name = node.superclass&.slice

        if class_name.end_with?("Test")
          command = "#{test_command} #{@path}"
          add_test_code_lens(node, name: class_name, command: command, kind: :group)
          @group_id_stack.push(@group_id)
          @group_id += 1
        end

        if superclass_name&.start_with?("ActiveRecord::Migration")
          command = "#{migrate_command} VERSION=#{migration_version}"
          add_migrate_code_lens(node, name: class_name, command: command)
        end
      end

      sig { params(node: Prism::ClassNode).void }
      def on_class_node_leave(node)
        class_name = node.constant_path.slice
        if class_name.end_with?("Test")
          @group_id_stack.pop
        end
      end

      private

      sig { returns(String) }
      def test_command
        "#{RbConfig.ruby} bin/rails test"
      end

      sig { returns(String) }
      def migrate_command
        "#{RbConfig.ruby} bin/rails db:migrate"
      end

      sig { returns(T.nilable(String)) }
      def migration_version
        File.basename(T.must(@path)).split("_").first
      end

      sig { params(node: Prism::Node, name: String, command: String).void }
      def add_migrate_code_lens(node, name:, command:)
        return unless @path

        @response_builder << create_code_lens(
          node,
          title: "Run",
          command_name: "rubyLsp.runTask",
          arguments: [command],
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

        @response_builder << create_code_lens(
          node,
          title: "Run",
          command_name: "rubyLsp.runTest",
          arguments: arguments,
          data: { type: "test", **grouping_data },
        )

        @response_builder << create_code_lens(
          node,
          title: "Run In Terminal",
          command_name: "rubyLsp.runTestInTerminal",
          arguments: arguments,
          data: { type: "test_in_terminal", **grouping_data },
        )

        @response_builder << create_code_lens(
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
