# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class Hover < ::RubyLsp::Listener
      extend T::Sig
      extend T::Generic

      ResponseType = type_member { { fixed: T.nilable(::RubyLsp::Interface::Hover) } }

      ::RubyLsp::Requests::Hover.add_listener(self)

      sig { override.returns(ResponseType) }
      attr_reader :response

      sig { void }
      def initialize
        @response = T.let(nil, ResponseType)
        super
      end

      listener_events do
        sig { params(node: SyntaxTree::Const).void }
        def on_const(node)
          model = RailsClient.instance.model(node.value)
          return if model.nil?

          schema_file = model[:schema_file]
          content = +""
          if schema_file
            content << "[Schema](file://#{schema_file})\n\n"
          end
          content << model[:columns].map { |name, type| "**#{name}**: #{type}\n" }.join("\n")
          contents = RubyLsp::Interface::MarkupContent.new(kind: "markdown", value: content)
          @response = RubyLsp::Interface::Hover.new(range: range_from_syntax_tree_node(node), contents: contents)
        end
      end
    end
  end
end
