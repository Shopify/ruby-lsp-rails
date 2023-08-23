# typed: strict
# frozen_string_literal: true

require_relative "support/rails_document_client"

module RubyLsp
  module Rails
    # ![Hover demo](../../hover.gif)
    #
    # Augment [hover](https://microsoft.github.io/language-server-protocol/specification#textDocument_hover) with
    # information about a model.
    #
    # # Example
    #
    # ```ruby
    # User.all
    # # ^ hovering here will show information about the User model
    # ```
    class Hover < ::RubyLsp::Listener
      extend T::Sig
      extend T::Generic

      ResponseType = type_member { { fixed: T.nilable(::RubyLsp::Interface::Hover) } }

      sig { override.returns(ResponseType) }
      attr_reader :response

      sig { params(client: RailsClient, emitter: RubyLsp::EventEmitter, message_queue: Thread::Queue).void }
      def initialize(client, emitter, message_queue)
        super(emitter, message_queue)

        @response = T.let(nil, ResponseType)
        @client = client
        emitter.register(self, :on_const, :on_command, :on_const_path_ref, :on_call)
      end

      sig { params(node: SyntaxTree::Const).void }
      def on_const(node)
        model = @client.model(node.value)
        return if model.nil?

        schema_file = model[:schema_file]
        content = +""
        if schema_file
          content << "[Schema](#{URI::Generic.build(scheme: "file", path: schema_file)})\n\n"
        end
        content << model[:columns].map { |name, type| "**#{name}**: #{type}\n" }.join("\n")
        contents = RubyLsp::Interface::MarkupContent.new(kind: "markdown", value: content)
        @response = RubyLsp::Interface::Hover.new(range: range_from_syntax_tree_node(node), contents: contents)
      end

      sig { params(node: SyntaxTree::Command).void }
      def on_command(node)
        message = node.message
        @response = generate_rails_document_link_hover(message.value, message)
      end

      sig { params(node: SyntaxTree::ConstPathRef).void }
      def on_const_path_ref(node)
        @response = generate_rails_document_link_hover(full_constant_name(node), node)
      end

      sig { params(node: SyntaxTree::CallNode).void }
      def on_call(node)
        message = node.message
        return if message.is_a?(Symbol)

        @response = generate_rails_document_link_hover(message.value, message)
      end

      private

      sig { params(name: String, node: SyntaxTree::Node).returns(T.nilable(Interface::Hover)) }
      def generate_rails_document_link_hover(name, node)
        urls = Support::RailsDocumentClient.generate_rails_document_urls(name)
        return if urls.empty?

        contents = RubyLsp::Interface::MarkupContent.new(kind: "markdown", value: urls.join("\n\n"))
        RubyLsp::Interface::Hover.new(range: range_from_syntax_tree_node(node), contents: contents)
      end
    end
  end
end
