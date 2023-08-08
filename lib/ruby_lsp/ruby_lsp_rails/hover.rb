# typed: strict
# frozen_string_literal: true

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
        emitter.register(self, :on_const)
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
    end
  end
end
