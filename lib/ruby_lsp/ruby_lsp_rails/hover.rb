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

      sig do
        params(
          client: RailsClient,
          nesting: T::Array[String],
          index: RubyIndexer::Index,
          dispatcher: Prism::Dispatcher,
          message_queue: Thread::Queue,
        ).void
      end
      def initialize(client, nesting, index, dispatcher, message_queue)
        super(dispatcher, message_queue)

        @_response = T.let(nil, ResponseType)
        @client = client
        @nesting = nesting
        @index = index
        dispatcher.register(self, :on_constant_path_node_enter, :on_constant_read_node_enter, :on_call_node_enter)
      end

      sig { params(node: Prism::ConstantPathNode).void }
      def on_constant_path_node_enter(node)
        entries = @index.resolve(node.slice, @nesting)
        return unless entries

        name = T.must(entries.first).name
        content = +""
        column_info = generate_column_content(name)
        content << column_info if column_info

        urls = Support::RailsDocumentClient.generate_rails_document_urls(name)
        content << urls.join("\n\n") unless urls.empty?
        return if content.empty?

        contents = RubyLsp::Interface::MarkupContent.new(kind: "markdown", value: content)
        @_response = RubyLsp::Interface::Hover.new(range: range_from_location(node.location), contents: contents)
      end

      sig { params(node: Prism::ConstantReadNode).void }
      def on_constant_read_node_enter(node)
        entries = @index.resolve(node.name.to_s, @nesting)
        return unless entries

        content = generate_column_content(T.must(entries.first).name)
        return unless content

        contents = RubyLsp::Interface::MarkupContent.new(kind: "markdown", value: content)
        @_response = RubyLsp::Interface::Hover.new(range: range_from_location(node.location), contents: contents)
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        message_value = node.message
        message_loc = node.message_loc

        return unless message_value && message_loc

        @_response = generate_rails_document_link_hover(message_value, message_loc)
      end

      private

      sig { params(name: String).returns(T.nilable(String)) }
      def generate_column_content(name)
        model = @client.model(name)
        return if model.nil?

        schema_file = model[:schema_file]
        content = +""
        content << "[Schema](#{URI::Generic.build(scheme: "file", path: schema_file)})\n\n" if schema_file
        content << model[:columns].map { |name, type| "**#{name}**: #{type}\n" }.join("\n")
        content
      end

      sig { params(name: String, location: Prism::Location).returns(T.nilable(Interface::Hover)) }
      def generate_rails_document_link_hover(name, location)
        urls = Support::RailsDocumentClient.generate_rails_document_urls(name)
        return if urls.empty?

        contents = RubyLsp::Interface::MarkupContent.new(kind: "markdown", value: urls.join("\n\n"))
        RubyLsp::Interface::Hover.new(range: range_from_location(location), contents: contents)
      end
    end
  end
end
