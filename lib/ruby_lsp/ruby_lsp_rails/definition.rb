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
      extend T::Sig
      include Requests::Support::Common

      sig do
        params(
          client: RunnerClient,
          response_builder: RubyLsp::ResponseBuilders::CollectionResponseBuilder[T.any(
            Interface::Location, Interface::LocationLink
          )],
          node_context: NodeContext,
          index: RubyIndexer::Index,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def initialize(client, response_builder, node_context, index, dispatcher)
        @client = client
        @response_builder = response_builder
        @node_context = node_context
        @nesting = T.let(node_context.nesting, T::Array[String])
        @index = index

        dispatcher.register(self, :on_call_node_enter, :on_symbol_node_enter, :on_string_node_enter)
      end

      sig { params(node: Prism::SymbolNode).void }
      def on_symbol_node_enter(node)
        handle_possible_dsl(node)
      end

      sig { params(node: Prism::StringNode).void }
      def on_string_node_enter(node)
        handle_possible_dsl(node)
      end

      sig { params(node: T.any(Prism::SymbolNode, Prism::StringNode)).void }
      def handle_possible_dsl(node)
        node = @node_context.call_node
        return unless node
        return unless self_receiver?(node)

        message = node.message

        return unless message

        if Support::Associations::ALL.include?(message)
          handle_association(node)
        elsif Support::Callbacks::ALL.include?(message)
          handle_callback(node)
        end
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        return unless self_receiver?(node)

        message = node.message

        return unless message

        if message.end_with?("_path") || message.end_with?("_url")
          handle_route(node)
        end
      end

      private

      sig { params(node: Prism::CallNode).void }
      def handle_callback(node)
        arguments = node.arguments&.arguments
        return unless arguments&.any?

        arguments.each do |argument|
          name = case argument
          when Prism::SymbolNode
            argument.value
          when Prism::StringNode
            argument.content
          end

          next unless name

          collect_definitions(name)
        end
      end

      sig { params(node: Prism::CallNode).void }
      def handle_association(node)
        first_argument = node.arguments&.arguments&.first
        return unless first_argument.is_a?(Prism::SymbolNode)

        association_name = first_argument.unescaped

        result = @client.association_target_location(
          model_name: @nesting.join("::"),
          association_name: association_name,
        )

        return unless result

        @response_builder << Support::LocationBuilder.line_location_from_s(result.fetch(:location))
      end

      sig { params(node: Prism::CallNode).void }
      def handle_route(node)
        result = @client.route_location(T.must(node.message))
        return unless result

        @response_builder << Support::LocationBuilder.line_location_from_s(result.fetch(:location))
      end

      sig { params(name: String).void }
      def collect_definitions(name)
        methods = @index.resolve_method(name, @nesting.join("::"))
        return unless methods

        methods.each do |target_method|
          location = target_method.location
          file_path = target_method.file_path

          @response_builder << Interface::Location.new(
            uri: URI::Generic.from_path(path: file_path).to_s,
            range: Interface::Range.new(
              start: Interface::Position.new(line: location.start_line - 1, character: location.start_column),
              end: Interface::Position.new(line: location.end_line - 1, character: location.end_column),
            ),
          )
        end
      end
    end
  end
end
