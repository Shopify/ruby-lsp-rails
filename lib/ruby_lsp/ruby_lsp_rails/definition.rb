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
    # - Classes
    # - Modules
    # - Constants
    # - Require paths
    # - Methods invoked on self only
    #
    # # Example
    #
    # ```ruby
    # require "some_gem/file" # <- Request go to definition on this string will take you to the file
    # Product.new # <- Request go to definition on this class name will take you to its declaration.
    # ```
    class Definition
      extend T::Sig
      include Requests::Support::Common
      include ActiveSupportTestCaseHelper

      MODEL_CALLBACKS = T.let(
        [
          "before_validation",
          "after_validation",
          "before_save",
          "around_save",
          "after_save",
          "before_create",
          "around_create",
          "after_create",
          "after_commit",
          "after_rollback",
          "before_update",
          "around_update",
          "after_update",
          "before_destroy",
          "around_destroy",
          "after_destroy",
          "after_initialize",
          "after_find",
          "after_touch",
        ].freeze,
        T::Array[String],
      )

      CONTROLLER_CALLBACKS = T.let(
        [
          "after_action",
          "append_after_action",
          "append_around_action",
          "append_before_action",
          "around_action",
          "before_action",
          "prepend_after_action",
          "prepend_around_action",
          "prepend_before_action",
          "skip_after_action",
          "skip_around_action",
          "skip_before_action",
        ].freeze,
        T::Array[String],
      )

      JOB_CALLBACKS = T.let(
        [
          "after_enqueue",
          "after_perform",
          "around_enqueue",
          "around_perform",
          "before_enqueue",
          "before_perform",
        ].freeze,
        T::Array[String],
      )

      CALLBACKS = T.let((MODEL_CALLBACKS + CONTROLLER_CALLBACKS + JOB_CALLBACKS).freeze, T::Array[String])

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

        return unless message && CALLBACKS.include?(message)

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
