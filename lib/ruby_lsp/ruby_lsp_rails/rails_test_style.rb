# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class RailsTestStyle < Listeners::TestDiscovery
      #: (RunnerClient client, ResponseBuilders::TestCollection response_builder, GlobalState global_state, Prism::Dispatcher dispatcher, URI::Generic uri) -> void
      def initialize(client, response_builder, global_state, dispatcher, uri)
        super(response_builder, global_state, dispatcher, uri)

        dispatcher.register(
          self,
          :on_class_node_enter,
          :on_call_node_enter,
          :on_def_node_enter,
        )
      end

      #: (Prism::ClassNode node) -> void
      def on_class_node_enter(node)
        with_test_ancestor_tracking(node) do |name, ancestors|
          if declarative_minitest?(ancestors, name)
            test_item = Requests::Support::TestItem.new(
              name,
              name,
              @uri,
              range_from_node(node),
              framework: :rails,
            )

            @response_builder.add(test_item)
          end
        end
      end

      #: (Prism::DefNode node) -> void
      def on_def_node_enter(node)
        return if @visibility_stack.last != :public

        name = node.name.to_s
        return unless name.start_with?("test_")

        add_test_item(node, name)
      end

      private

      #: (Array[String] attached_ancestors, String fully_qualified_name) -> bool
      def declarative_minitest?(attached_ancestors, fully_qualified_name)
        # The declarative test style is present as long as the class extends
        # ActiveSupport::Testing::Declarative
        name_parts = fully_qualified_name.split("::")
        singleton_name = "#{name_parts.join("::")}::<Class:#{name_parts.last}>"
        @index.linearized_ancestors_of(singleton_name).include?("ActiveSupport::Testing::Declarative")
      rescue RubyIndexer::Index::NonExistingNamespaceError
        false
      end

      #: (Prism::Node node, String test_name) -> void
      def add_test_item(node, test_name)
        test_item = group_test_item
        return unless test_item

        test_item.add(Requests::Support::TestItem.new(
          "#{test_item.id}##{test_name}",
          test_name,
          @uri,
          range_from_node(node),
          framework: :rails,
        ))
      end

      #: -> Requests::Support::TestItem?
      def group_test_item
        current_group_name = RubyIndexer::Index.actual_nesting(@nesting, nil).join("::")

        # If we're finding a test method, but for the wrong framework, then the group test item will not have been
        # previously pushed and thus we return early and avoid adding items for a framework this listener is not
        # interested in
        @response_builder[current_group_name]
      end
    end
  end
end
