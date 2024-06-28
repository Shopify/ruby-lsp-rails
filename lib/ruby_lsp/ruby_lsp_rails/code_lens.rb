# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    # ![CodeLens demo](../../code_lens.gif)
    #
    # This feature adds Code Lens features for Rails applications.
    #
    # For Active Support test cases:
    #
    # - Run tests in the VS Terminal
    # - Run tests in the VS Code Test Explorer
    # - Debug tests
    #
    # For Rails controllers:
    #
    # - See the path corresponding to an action
    # - Click on the action's Code Lens to jump to its declaration in the routes.
    #
    # Note: This depends on a support for the `rubyLsp.openFile` command.
    # For the VS Code extension this is built-in, but for other editors this may require some custom configuration.
    #
    # The
    # [code lens](https://microsoft.github.io/language-server-protocol/specification#textDocument_codeLens)
    # request informs the editor of runnable commands such as tests.
    # It's available for tests which inherit from `ActiveSupport::TestCase` or one of its descendants, such as
    # `ActionDispatch::IntegrationTest`.
    #
    # A code lens can be _unresolved_, meaning no command is associated with it.
    #
    # # Examples:
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
    # ```
    #
    # The code lenses will be displayed above the class and above each test method.
    #
    # Note: When using the Test Explorer view, if your code contains a statement to pause execution (e.g. `debugger`) it
    # will cause the test runner to hang.
    #
    # For the following code, assuming the routing contains `resources :users`, a Code Lens will be seen above each
    # action.
    #
    # ```ruby
    # class UsersController < ApplicationController
    #   GET /users(.:format)
    #   def index # <- Will show code lens above for the path
    #   end
    # end
    # ```
    #
    # Note: Complex routing configurations may not be supported.
    #
    class CodeLens
      extend T::Sig
      include Requests::Support::Common
      include ActiveSupportTestCaseHelper

      sig do
        params(
          client: RunnerClient,
          response_builder:  ResponseBuilders::CollectionResponseBuilder[Interface::CodeLens],
          uri: URI::Generic,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def initialize(client, response_builder, uri, dispatcher)
        @client = client
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

        if class_name.end_with?("Controller") && superclass_name&.end_with?("Controller")
          add_route_code_lenses_to_actions(node)
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

      sig { params(node: Prism::ClassNode).void }
      def add_route_code_lenses_to_actions(node)
        public_method_nodes = T.must(node.body).child_nodes.take_while do |node|
          !node.is_a?(Prism::CallNode) || ![:protected, :private].include?(node.name)
        end
        public_method_nodes.grep(Prism::DefNode).each do |public_method_node|
          add_route_code_lens_to_action(public_method_node, class_node: node)
        end
      end

      sig { params(node: Prism::DefNode, class_node: Prism::ClassNode).void }
      def add_route_code_lens_to_action(node, class_node:)
        route = @client.route(
          controller: class_node.constant_path.slice,
          action: node.name.to_s,
        )

        return unless route

        path = route[:path]
        verb = route[:verb]
        source_location = route[:source_location]

        arguments = [
          source_location,
          {
            start_line: node.location.start_line - 1,
            start_column: node.location.start_column,
            end_line: node.location.end_line - 1,
            end_column: node.location.end_column,
          },
        ]

        @response_builder << create_code_lens(
          node,
          title: [verb, path].join(" "),
          command_name: "rubyLsp.openFile",
          arguments: arguments,
          data: { type: "file" },
        )
      end

      sig { returns(String) }
      def test_command
        if Gem.win_platform?
          "ruby bin/rails test"
        else
          "bin/rails test"
        end
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
