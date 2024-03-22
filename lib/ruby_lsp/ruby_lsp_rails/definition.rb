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
    # - Callbacks
    #
    # # Example
    #
    # ```ruby
    # before_action :foo # <- Go to definition on this symbol will jump to the method if it is defined in the same class
    # ```
    class Definition
      extend T::Sig
      include Requests::Support::Common

      sig do
        params(
          response_builder: ResponseBuilders::CollectionResponseBuilder[Interface::Location],
          nesting: T::Array[String],
          index: RubyIndexer::Index,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def initialize(response_builder, nesting, index, dispatcher)
        @response_builder = response_builder
        @nesting = nesting
        @index = index

        dispatcher.register(self, :on_call_node_enter)
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        return unless self_receiver?(node)

        message = node.message

        return unless message && Support::Callbacks::ALL.include?(message)

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

      private

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
