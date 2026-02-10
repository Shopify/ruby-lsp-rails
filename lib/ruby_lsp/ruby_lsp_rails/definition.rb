# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    # ![Definition demo](../../definition.gif)
    #
    # The [definition
    # request](https://microsoft.github.io/language-server-protocol/specification#textDocument_definition) jumps to the
    # definition of the symbol under the cursor.
    #
    # Currently supported targets:
    #
    # - Callbacks
    # - Named routes (e.g. `users_path`)
    #
    # # Example
    #
    # ```ruby
    # before_action :foo # <- Go to definition on this symbol will jump to the method
    # ```
    #
    # Notes for named routes:
    #
    # - It is available only in Rails 7.1 or newer.
    # - Route may be defined across multiple files, e.g. using `draw`, rather than in `routes.rb`.
    # - Routes won't be found if not defined for the Rails development environment.
    # - If using `constraints`, the route can only be found if the constraints are met.
    # - Changes to routes won't be picked up until the server is restarted.
    class Definition
      include Requests::Support::Common

      #: (RunnerClient client, RubyLsp::ResponseBuilders::CollectionResponseBuilder[(Interface::Location | Interface::LocationLink)] response_builder, NodeContext node_context, RubyIndexer::Index index, Prism::Dispatcher dispatcher, URI::Generic uri) -> void
      def initialize(client, response_builder, node_context, index, dispatcher, uri)
        @client = client
        @response_builder = response_builder
        @node_context = node_context
        @nesting = node_context.nesting #: Array[String]
        @index = index
        @uri = uri

        dispatcher.register(self, :on_call_node_enter, :on_symbol_node_enter, :on_string_node_enter)
      end

      #: (Prism::SymbolNode node) -> void
      def on_symbol_node_enter(node)
        handle_possible_dsl(node)
      end

      #: (Prism::StringNode node) -> void
      def on_string_node_enter(node)
        handle_possible_dsl(node)
      end

      #: (Prism::CallNode node) -> void
      def on_call_node_enter(node)
        return unless self_receiver?(node)

        message = node.message

        return unless message

        if message.end_with?("_path") || message.end_with?("_url")
          handle_route(node)
        end
      end

      private

      #: ((Prism::SymbolNode | Prism::StringNode) node) -> void
      def handle_possible_dsl(node)
        call_node = @node_context.call_node
        return unless call_node
        return unless self_receiver?(call_node)

        message = call_node.message

        return unless message

        arguments = call_node.arguments&.arguments
        return unless arguments

        if Support::Associations::ALL.include?(message)
          handle_association(node, arguments)
        elsif Support::Callbacks::ALL.include?(message)
          handle_callback(node, call_node, arguments)
          handle_if_unless_conditional(node, call_node, arguments)
        elsif Support::Validations::ALL.include?(message)
          handle_validation(node, call_node, arguments)
          handle_if_unless_conditional(node, call_node, arguments)
        end
      end

      #: ((Prism::SymbolNode | Prism::StringNode) node, Array[Prism::Node] arguments) -> void
      def handle_association(node, arguments)
        association_name_node = arguments.first
        through_node = extract_option_value(arguments, "through")
        class_name_node = extract_option_value(arguments, "class_name")

        case node
        when association_name_node
          handle_association_name(association_name_node, class_name_node)
        when through_node
          handle_through_option(node)
        when class_name_node
          goto_class(node.content)
        end
      end

      #: (Array[Prism::Node] arguments, String option_name) -> Prism::Node?
      def extract_option_value(arguments, option_name)
        keyword_hash = arguments.find { |arg| arg.is_a?(Prism::KeywordHashNode) } #: as Prism::KeywordHashNode?
        return unless keyword_hash

        assoc = keyword_hash.elements.find do |element|
          element.is_a?(Prism::AssocNode) &&
            element.key.is_a?(Prism::SymbolNode) &&
            element.key.value == option_name
        end #: as Prism::AssocNode?

        assoc&.value
      end

      #: (Prism::SymbolNode node, Prism::Node? class_name_node) -> void
      def handle_association_name(node, class_name_node)
        # If class_name is specified, use it directly from the index
        if class_name_node.is_a?(Prism::StringNode)
          goto_class(class_name_node.content)
          return
        end

        # Otherwise, ask Rails for the associated model
        result = @client.association_target(
          model_name: @nesting.join("::"),
          association_name: node.unescaped,
        )

        return unless result

        @response_builder << Support::LocationBuilder.line_location_from_s(result.fetch(:location))
      end

      #: (String class_name) -> void
      def goto_class(class_name)
        entries = @index[class_name]
        return unless entries

        entries.each do |entry|
          @response_builder << Interface::Location.new(
            uri: entry.uri.to_s,
            range: range_from_location(entry.location),
            )
        end
      end

      #: ((Prism::SymbolNode | Prism::StringNode) node) -> void
      def handle_through_option(node)
        return unless node.is_a?(Prism::SymbolNode)

        association_call = find_association_in_nesting_nodes(node.unescaped)
        return unless association_call

        @response_builder << Interface::Location.new(
          uri: @uri.to_s,
          range: range_from_location(association_call.location),
        )
      end

      #: (String association_name) -> Prism::CallNode?
      def find_association_in_nesting_nodes(association_name)
        nesting_nodes = @node_context.instance_variable_get(:@nesting_nodes) #: as Array[Prism::Node]

        nesting_nodes.each do |nesting_node|
          body = case nesting_node
          when Prism::ClassNode, Prism::ModuleNode
            nesting_node.body
          end

          next unless body.is_a?(Prism::StatementsNode)

          match = body.body.find do |statement|
            next unless statement.is_a?(Prism::CallNode)
            next unless Support::Associations::ALL.include?(statement.message)

            first_arg = statement.arguments&.arguments&.first
            first_arg.is_a?(Prism::SymbolNode) && first_arg.unescaped == association_name
          end #: as Prism::CallNode?

          return match if match
        end

        nil
      end

      #: ((Prism::SymbolNode | Prism::StringNode) node, Prism::CallNode call_node, Array[Prism::Node] arguments) -> void
      def handle_callback(node, call_node, arguments)
        focus_argument = arguments.find { |argument| argument == node }

        name = case focus_argument
        when Prism::SymbolNode
          focus_argument.value
        when Prism::StringNode
          focus_argument.content
        end

        return unless name

        collect_definitions(name)
      end

      #: ((Prism::SymbolNode | Prism::StringNode) node, Prism::CallNode call_node, Array[Prism::Node] arguments) -> void
      def handle_validation(node, call_node, arguments)
        message = call_node.message
        return unless message

        focus_argument = arguments.find { |argument| argument == node }
        return unless focus_argument

        return unless node.is_a?(Prism::SymbolNode)

        name = node.value
        return unless name

        # validates_with uses constants, not symbols - skip (handled by constant resolution)
        return if message == "validates_with"

        collect_definitions(name)
      end

      #: (Prism::CallNode node) -> void
      def handle_route(node)
        result = @client.route_location(
          node.message, #: as !nil
        )
        return unless result

        @response_builder << Support::LocationBuilder.line_location_from_s(result.fetch(:location))
      end

      #: (String name) -> void
      def collect_definitions(name)
        methods = @index.resolve_method(name, @nesting.join("::"))
        return unless methods

        methods.each do |target_method|
          @response_builder << Interface::Location.new(
            uri: target_method.uri.to_s,
            range: range_from_location(target_method.location),
          )
        end
      end

      #: ((Prism::SymbolNode | Prism::StringNode) node, Prism::CallNode call_node, Array[Prism::Node] arguments) -> void
      def handle_if_unless_conditional(node, call_node, arguments)
        keyword_arguments = arguments.find { |argument| argument.is_a?(Prism::KeywordHashNode) } #: as Prism::KeywordHashNode?
        return unless keyword_arguments

        element = keyword_arguments.elements.find do |element|
          next false unless element.is_a?(Prism::AssocNode)

          key = element.key
          next false unless key.is_a?(Prism::SymbolNode)

          key_value = key.value
          next false unless key_value == "if" || key_value == "unless"

          value = element.value
          next false unless value.is_a?(Prism::SymbolNode)

          value == node
        end #: as Prism::AssocNode?

        return unless element

        value = element.value #: as Prism::SymbolNode
        method_name = value.value

        return unless method_name

        collect_definitions(method_name)
      end
    end
  end
end
