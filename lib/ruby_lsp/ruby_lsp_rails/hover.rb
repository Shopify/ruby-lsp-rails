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
      attr_reader :_response

      sig { params(client: RailsClient, emitter: RubyLsp::EventEmitter, message_queue: Thread::Queue).void }
      def initialize(client, emitter, message_queue)
        super(emitter, message_queue)

        @_response = T.let(nil, ResponseType)
        @client = client
        emitter.register(self, :on_constant_path, :on_constant_read, :on_call)
      end

      sig { params(node: YARP::ConstantPathNode).void }
      def on_constant_path(node)
        @_response = generate_rails_document_link_hover(node.slice, node.location)
      end

      sig { params(node: YARP::ConstantReadNode).void }
      def on_constant_read(node)
        model = @client.model(node.name.to_s)
        return if model.nil?

        schema_file = model[:schema_file]
        content = +""
        if schema_file
          content << "[Schema](#{URI::Generic.build(scheme: "file", path: schema_file)})\n\n"
        end
        content << model[:columns].map { |name, type| "**#{name}**: #{type}\n" }.join("\n")
        contents = RubyLsp::Interface::MarkupContent.new(kind: "markdown", value: content)
        @_response = RubyLsp::Interface::Hover.new(range: range_from_node(node), contents: contents)
      end

      sig { params(node: YARP::CallNode).void }
      def on_call(node)
        message_value = node.message
        message_loc = node.message_loc

        return unless message_value && message_loc

        @_response = generate_rails_document_link_hover(message_value, message_loc)
      end

      private

      sig { params(name: String, location: YARP::Location).returns(T.nilable(Interface::Hover)) }
      def generate_rails_document_link_hover(name, location)
        urls = Support::RailsDocumentClient.generate_rails_document_urls(name)
        return if urls.empty?

        contents = RubyLsp::Interface::MarkupContent.new(kind: "markdown", value: urls.join("\n\n"))
        RubyLsp::Interface::Hover.new(range: range_from_location(location), contents: contents)
      end
    end
  end
end
