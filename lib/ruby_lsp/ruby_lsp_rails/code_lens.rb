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
    # - Run migrations in the VS Terminal
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
    # ```
    #
    # # Example:
    # ```ruby
    # Run
    # class AddFirstNameToUsers < ActiveRecord::Migration[7.1]
    #   # ...
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
          global_state: GlobalState,
          response_builder:  ResponseBuilders::CollectionResponseBuilder[Interface::CodeLens],
          uri: URI::Generic,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def initialize(client, global_state, response_builder, uri, dispatcher)
        @client = client
        @global_state = global_state
        @response_builder = response_builder
        @path = T.let(uri.to_standardized_path, T.nilable(String))
        @group_id = T.let(1, Integer)
        @group_id_stack = T.let([], T::Array[Integer])
        @constant_name_stack = T.let([], T::Array[[String, T.nilable(String)]])

        dispatcher.register(
          self,
          :on_call_node_enter,
          :on_class_node_enter,
          :on_def_node_enter,
          :on_class_node_leave,
          :on_module_node_enter,
          :on_module_node_leave,
        )
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

        if controller?
          add_route_code_lens_to_action(node)
          add_jump_to_view(node)
        end
      end

      sig { params(node: Prism::ClassNode).void }
      def on_class_node_enter(node)
        class_name = node.constant_path.slice
        superclass_name = node.superclass&.slice

        # We need to use a stack because someone could define a nested class
        # inside a controller. When we exit that nested class declaration, we are
        # back in a controller context. This part is used in other places in the LSP
        @constant_name_stack << [class_name, superclass_name]

        if class_name.end_with?("Test")
          fully_qualified_name = @constant_name_stack.map(&:first).join("::")
          command = "#{test_command} #{@path} --name \"/#{Shellwords.escape(fully_qualified_name)}(#|::)/\""
          add_test_code_lens(node, name: class_name, command: command, kind: :group)
          @group_id_stack.push(@group_id)
          @group_id += 1
        end

        if @path && superclass_name&.start_with?("ActiveRecord::Migration")
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

        @constant_name_stack.pop
      end

      sig { params(node: Prism::ModuleNode).void }
      def on_module_node_enter(node)
        @constant_name_stack << [node.constant_path.slice, nil]
      end

      sig { params(node: Prism::ModuleNode).void }
      def on_module_node_leave(node)
        @constant_name_stack.pop
      end

      private

      sig { returns(T.nilable(T::Boolean)) }
      def controller?
        class_name, superclass_name = @constant_name_stack.last
        return false unless class_name && superclass_name

        class_name.end_with?("Controller") && superclass_name.end_with?("Controller")
      end

      sig { params(node: Prism::DefNode).void }
      def add_jump_to_view(node)
        class_name = @constant_name_stack.map(&:first).join("::")
        action_name = node.name
        controller_name = class_name
          .delete_suffix("Controller")
          .gsub(/([a-z])([A-Z])/, "\\1_\\2")
          .gsub("::", "/")
          .downcase

        view_uris = Dir.glob("#{@client.rails_root}/app/views/#{controller_name}/#{action_name}*").filter_map do |path|
          # it's possible we could have a directory with the same name as the action, so we need to skip those
          next if File.directory?(path)

          URI::Generic.from_path(path: path).to_s
        end

        return if view_uris.empty?

        @response_builder << create_code_lens(
          node,
          title: "Jump to view",
          command_name: "rubyLsp.openFile",
          arguments: [view_uris],
          data: { type: "file" },
        )
      end

      sig { params(node: Prism::DefNode).void }
      def add_route_code_lens_to_action(node)
        class_name, _ = T.must(@constant_name_stack.last)
        route = @client.route(controller: class_name, action: node.name.to_s)
        return unless route

        file_path, line = route[:source_location]

        @response_builder << create_code_lens(
          node,
          title: "#{route[:verb]} #{route[:path]}",
          command_name: "rubyLsp.openFile",
          arguments: [["file://#{file_path}#L#{line}"]],
          data: { type: "file" },
        )
      end

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
        return unless @global_state.test_library == "rails"

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
