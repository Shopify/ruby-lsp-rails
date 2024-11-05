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
    class Hover
      extend T::Sig
      include Requests::Support::Common

      sig do
        params(
          client: RunnerClient,
          response_builder: ResponseBuilders::Hover,
          node_context: NodeContext,
          global_state: GlobalState,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def initialize(client, response_builder, node_context, global_state, dispatcher)
        @client = client
        @response_builder = response_builder
        @nesting = T.let(node_context.nesting, T::Array[String])
        @index = T.let(global_state.index, RubyIndexer::Index)
        dispatcher.register(self, :on_constant_path_node_enter, :on_constant_read_node_enter)
      end

      sig { params(node: Prism::ConstantPathNode).void }
      def on_constant_path_node_enter(node)
        entries = @index.resolve(node.slice, @nesting)
        return unless entries

        name = T.must(entries.first).name
        generate_column_content(name)
      end

      sig { params(node: Prism::ConstantReadNode).void }
      def on_constant_read_node_enter(node)
        entries = @index.resolve(node.name.to_s, @nesting)
        return unless entries

        generate_column_content(T.must(entries.first).name)
      end

      private

      sig { params(name: String).void }
      def generate_column_content(name)
        model = @client.model(name)
        return if model.nil?

        schema_file = model[:schema_file]

        @response_builder.push(
          "[Schema](#{URI::Generic.from_path(path: schema_file)})\n",
          category: :documentation,
        ) if schema_file

        @response_builder.push(
          model[:columns].map do |name, type, default_value, nullable|
            primary_key_suffix = " (PK)" if model[:primary_keys].include?(name)
            suffixes = []
            suffixes << "default: #{format_default(default_value, type)}" if default_value
            suffixes << "not null" unless nullable || primary_key_suffix
            suffix_string = " - #{suffixes.join(" - ")}" if suffixes.any?
            "**#{name}**: #{type}#{primary_key_suffix}#{suffix_string}\n"
          end.join("\n"),
          category: :documentation,
        )
      end

      sig { params(default_value: String, type: String).returns(String) }
      def format_default(default_value, type)
        case type
        when "boolean"
          default_value == "true" ? "true" : "false"
        when "string"
          default_value.inspect
        else
          default_value
        end
      end
    end
  end
end
