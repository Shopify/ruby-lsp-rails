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
      include Requests::Support::Common

      #: (RunnerClient client, ResponseBuilders::Hover response_builder, NodeContext node_context, GlobalState global_state, Prism::Dispatcher dispatcher) -> void
      def initialize(client, response_builder, node_context, global_state, dispatcher)
        @client = client
        @response_builder = response_builder
        @node_context = node_context
        @nesting = node_context.nesting #: Array[String]
        @index = global_state.index #: RubyIndexer::Index
        dispatcher.register(
          self,
          :on_constant_path_node_enter,
          :on_constant_read_node_enter,
          :on_symbol_node_enter,
          :on_string_node_enter,
        )
      end

      #: (Prism::ConstantPathNode node) -> void
      def on_constant_path_node_enter(node)
        entries = @index.resolve(node.slice, @nesting)
        item = entries&.first
        return unless item

        name = item.name
        generate_column_content(name)
      end

      #: (Prism::ConstantReadNode node) -> void
      def on_constant_read_node_enter(node)
        entries = @index.resolve(node.name.to_s, @nesting)
        item = entries&.first
        return unless item

        generate_column_content(item.name)
      end

      #: (Prism::SymbolNode node) -> void
      def on_symbol_node_enter(node)
        handle_possible_dsl(node)
      end

      #: (Prism::StringNode node) -> void
      def on_string_node_enter(node)
        handle_possible_dsl(node)
      end

      private

      #: (String name) -> void
      def generate_column_content(name)
        model = @client.model(name)
        return if model.nil?

        schema_file = model[:schema_file]

        @response_builder.push(
          "[Schema](#{URI::Generic.from_path(path: schema_file)})\n",
          category: :documentation,
        ) if schema_file

        if model[:columns].any?
          @response_builder.push(
            "### Columns",
            category: :documentation,
          )
          @response_builder.push(
            model[:columns].map do |name, type, default_value, nullable|
              primary_key_suffix = " (PK)" if model[:primary_keys].include?(name)
              foreign_key_suffix = " (FK)" if model[:foreign_keys].include?(name)
              suffixes = []
              suffixes << "default: #{format_default(default_value, type)}" if default_value
              suffixes << "not null" unless nullable || primary_key_suffix
              suffix_string = " - #{suffixes.join(" - ")}" if suffixes.any?
              "- **#{name}**: #{type}#{primary_key_suffix}#{foreign_key_suffix}#{suffix_string}\n"
            end.join("\n"),
            category: :documentation,
          )
        end

        if model[:indexes].any?
          @response_builder.push(
            "### Indexes",
            category: :documentation,
          )
          @response_builder.push(
            model[:indexes].map do |index|
              uniqueness = index[:unique] ? " (unique)" : ""
              "- **#{index[:name]}** (#{index[:columns].join(",")})#{uniqueness}"
            end.join("\n"),
            category: :documentation,
          )
        end
      end

      #: (String default_value, String type) -> String
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

      #: ((Prism::SymbolNode | Prism::StringNode) node) -> void
      def handle_possible_dsl(node)
        call_node = @node_context.call_node
        return unless call_node
        return unless self_receiver?(call_node)

        message = call_node.message
        return unless message

        if Support::Associations::ALL.include?(message)
          handle_association(node, call_node)
        end
      end

      #: ((Prism::SymbolNode | Prism::StringNode) node, Prism::CallNode call_node) -> void
      def handle_association(node, call_node)
        arguments = call_node.arguments&.arguments
        return unless arguments

        first_argument = arguments.first
        return unless first_argument.is_a?(Prism::SymbolNode) || first_argument.is_a?(Prism::StringNode)

        association_name = extract_string_from_node(first_argument)
        return unless association_name

        through_element = find_through_association_element(arguments)
        clicked_symbol = extract_string_from_node(node)
        return unless clicked_symbol

        if through_element
          through_association_name = extract_string_from_node(through_element.value)

          if clicked_symbol == association_name
            handle_association_name(association_name)
          elsif through_association_name && clicked_symbol == through_association_name
            handle_association_name(through_association_name)
          end
        else
          handle_association_name(association_name)
        end
      end

      #: (Array[Prism::Node]) -> Prism::AssocNode?
      def find_through_association_element(arguments)
        result = arguments
          .filter_map { |arg| arg.elements if arg.is_a?(Prism::KeywordHashNode) }
          .flatten
          .find do |elem|
            next false unless elem.is_a?(Prism::AssocNode)

            key = elem.key
            next false unless key.is_a?(Prism::SymbolNode)

            key.value == "through"
          end

        result if result.is_a?(Prism::AssocNode)
      end

      #: (String association_name) -> void
      def handle_association_name(association_name)
        result = @client.association_target(
          model_name: @nesting.join("::"),
          association_name: association_name,
        )

        return unless result

        generate_hover(result[:name])
      end

      # Copied from `RubyLsp::Listeners::Hover#generate_hover`
      #: (String name) -> void
      def generate_hover(name)
        entries = @index.resolve(name, @node_context.nesting)
        return unless entries

        # We should only show hover for private constants if the constant is defined in the same namespace as the
        # reference
        first_entry = entries.first #: as !nil
        full_name = first_entry.name
        return if first_entry.private? && full_name != "#{@node_context.fully_qualified_name}::#{name}"

        categorized_markdown_from_index_entries(full_name, entries).each do |category, content|
          @response_builder.push(content, category: category)
        end
      end

      #: (Prism::Node) -> String?
      def extract_string_from_node(node)
        case node
        when Prism::SymbolNode
          node.unescaped
        when Prism::StringNode
          node.content
        end
      end
    end
  end
end
