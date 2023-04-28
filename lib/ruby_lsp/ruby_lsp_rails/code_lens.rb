# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class CodeLens < ::RubyLsp::Listener
      extend T::Sig
      extend T::Generic

      ResponseType = type_member { { fixed: T.nilable(T::Array[::RubyLsp::Interface::CodeLens]) } }

      ::RubyLsp::Requests::CodeLens.add_listener(self)

      sig { override.returns(ResponseType) }
      attr_reader :response

      sig { params(uri: String, message_queue: Thread::Queue).void }
      def initialize(uri, message_queue)
        @response = T.let([], ResponseType)
        @visibility = T.let("public", String)
        @prev_visibility = T.let("public", String)
        @path = T.let(uri.delete_prefix("file://"), String)
        super
      end

      listener_events do
        sig { params(node: SyntaxTree::Command).void }
        def on_command(node)
          if @visibility == "public"
            message_value = node.message.value
            if message_value == "test" && node.arguments.parts.any?
              first_argument = node.arguments.parts.first
              method_name = first_argument.parts.first.value if first_argument.is_a?(SyntaxTree::StringLiteral)

              if method_name
                add_code_lens(
                  node,
                  name: method_name,
                  command: RubyLsp::Requests::CodeLens::BASE_COMMAND + @path + " --name " + "test_" + method_name.gsub(
                    " ", "_"
                  ),
                )
              end
            end
          end
        end

        sig { params(node: SyntaxTree::DefNode).void }
        def on_def(node); end
      end

      private

      sig { params(node: SyntaxTree::Node, name: String, command: String).void }
      def add_code_lens(node, name:, command:)
        @response << ::RubyLsp::Requests::CodeLens.create_code_lens(
          node,
          path: @path,
          name: name,
          test_command: command,
          type: "test",
        )

        @response << ::RubyLsp::Requests::CodeLens.create_code_lens(
          node,
          path: @path,
          name: name,
          test_command: command,
          type: "debug",
        )
      end
    end
  end
end
