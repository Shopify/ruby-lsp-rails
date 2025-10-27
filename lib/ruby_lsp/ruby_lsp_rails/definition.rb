# typed: strict
# frozen_string_literal: true

require "pathname"

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
      include Inflections

      #: (RunnerClient client, RubyLsp::ResponseBuilders::CollectionResponseBuilder[(Interface::Location | Interface::LocationLink)] response_builder, NodeContext node_context, RubyIndexer::Index index, Prism::Dispatcher dispatcher) -> void
      def initialize(client, response_builder, uri, node_context, index, dispatcher)
        @client = client
        @response_builder = response_builder
        @path = uri.to_standardized_path #: String?
        @node_context = node_context
        @nesting = node_context.nesting #: Array[String]
        @index = index

        dispatcher.register(self, :on_call_node_enter, :on_symbol_node_enter, :on_string_node_enter)
      end

      #: (Prism::SymbolNode node) -> void
      def on_symbol_node_enter(node)
        handle_possible_dsl(node)
      end

      #: (Prism::StringNode node) -> void
      def on_string_node_enter(node)
        handle_possible_dsl(node)
        handle_possible_render(node)
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
          handle_association(call_node)
        elsif Support::Callbacks::ALL.include?(message)
          handle_callback(node, call_node, arguments)
          handle_if_unless_conditional(node, call_node, arguments)
        elsif Support::Validations::ALL.include?(message)
          handle_validation(node, call_node, arguments)
          handle_if_unless_conditional(node, call_node, arguments)
        end
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
      def handle_association(node)
        first_argument = node.arguments&.arguments&.first
        return unless first_argument.is_a?(Prism::SymbolNode)

        association_name = first_argument.unescaped

        result = @client.association_target(
          model_name: @nesting.join("::"),
          association_name: association_name,
        )

        return unless result

        @response_builder << Support::LocationBuilder.line_location_from_s(result.fetch(:location))
      end

      def handle_possible_render(node)
        return unless @path&.end_with?(".html.erb")

        call_node = @node_context.call_node
        return unless call_node
        return unless self_receiver?(call_node)

        message = call_node.message
        return unless message == "render"

        arguments = call_node.arguments&.arguments
        return unless arguments

        argument = view_template_argument(arguments, node)
        return unless argument

        template = node.content
        template_options = view_template_options(arguments)

        formats_pattern = template_options[:formats] ? "{#{template_options[:formats].join(",")}}" : "html"
        variants_pattern = "{#{template_options[:variants].map { |variant| "+#{variant}" }.join(",")},}" if template_options[:variants]
        handlers_pattern = template_options[:handlers] ? "{#{template_options[:handlers].join(",")}}" : "*"

        extension_pattern = "#{formats_pattern}#{variants_pattern}.#{handlers_pattern}"

        template_pattern = if argument == "template"
          File.join(@client.views_dir, "#{template}.#{extension_pattern}")
        elsif template.include?("/")
          *partial_dir, partial_name = template.split("/")

          File.join(@client.views_dir, *partial_dir, "_#{partial_name}.#{extension_pattern}")
        else
          File.join(@client.views_dir, "{#{view_prefixes.join(",")}}", "_#{template}.#{extension_pattern}")
        end

        template_path = Dir.glob(template_pattern).first
        return unless template_path

        @response_builder << Support::LocationBuilder.line_location_from_s("#{template_path}:1")
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

      def view_template_argument(arguments, node)
        return "partial" if arguments.first == node

        kwargs = arguments.find { |argument| argument.is_a?(Prism::KeywordHashNode) }
        return unless kwargs

        kwarg = kwargs.elements.find do |pair|
          ["partial", "layout", "spacer_template", "template"].include?(pair.key.value) && pair.value == node
        end

        kwarg&.key&.value
      end

      def view_template_options(arguments)
        kwargs = arguments.find { |argument| argument.is_a?(Prism::KeywordHashNode) }
        return {} unless kwargs

        kwargs.elements.each_with_object({}) do |pair, options|
          next unless ["formats", "variants", "handlers"].include?(pair.key.value)

          value = [pair.value.value] if pair.value.is_a?(Prism::SymbolNode)
          value = pair.value.elements.map(&:value) if pair.value.is_a?(Prism::ArrayNode)

          options[pair.key.value.to_sym] = value
        end
      end

      # Resolve available directories from which the controller can render relative
      # partials based on its ancestry chain.
      def view_prefixes
        controller_dir = Pathname(@path).dirname.relative_path_from(@client.views_dir).to_s
        controller_class = "#{camelize(controller_dir)}Controller"
        controller_ancestors = [controller_class]

        controller_entry = @index.resolve(controller_class, [])&.find(&:parent_class)
        while controller_entry
          controller_entry = @index.resolve(controller_entry.parent_class, controller_entry.nesting)&.find(&:parent_class)
          break unless controller_entry && not_in_dependencies?(controller_entry.file_path)
          controller_ancestors << controller_entry.name
        end

        controller_ancestors.map { |ancestor| underscore(ancestor.delete_suffix("Controller")) }
      end
    end
  end
end
