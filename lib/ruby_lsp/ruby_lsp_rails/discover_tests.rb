# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class DiscoverTests
      include Requests::Support::Common
      DYNAMIC_REFERENCE_MARKER = T.let("<dynamic_reference>", String)

      # @override
      #: (ResponseBuilders::TestCollection response_builder, Prism::Dispatcher dispatcher, URI::Generic uri) -> void
      def initialize(response_builder, dispatcher, uri)
        @response_builder = response_builder
        @nesting = T.let([], T::Array[String])
        @uri = uri
        dispatcher.register(
          self,
          :on_class_node_enter,
          :on_class_node_leave,
          :on_module_node_enter,
          :on_module_node_leave,
          # :on_def_node_enter, # for 'classic' tests... do we need to handle here?
          :on_call_node_enter, # e.g. `test "..."`
          # :on_call_node_leave,
        )
      end

      #: (Prism::ClassNode node) -> void
      def on_class_node_enter(node)
        name = constant_name(node.constant_path)
        name ||= name_with_dynamic_reference(node.constant_path)

        @nesting << name
      end

      #: (Prism::ClassNode node) -> void
      def on_class_node_leave(node)
        @nesting.pop
      end

      #: (Prism::ModuleNode node) -> void
      def on_module_node_enter(node)
        name = constant_name(node.constant_path)
        name ||= name_with_dynamic_reference(node.constant_path)

        @nesting << name
      end

      #: (Prism::ModuleNode node) -> void
      def on_module_node_leave(node)
        @nesting.pop
      end

      #: (Prism::CallNode node) -> void
      def on_call_node_enter(node)
        return unless node.name == :test
        return unless node.block

        args = node.arguments&.arguments
        return unless args

        return unless args.first.is_a?(Prism::StringNode)

        name = T.must(args[0]).unescaped # right way to access?

        current_group_name = RubyIndexer::Index.actual_nesting(@nesting, nil).join("::")

        test_item = Requests::Support::TestItem.new(
          "#{current_group_name}##{name}",
          name,
          @uri,
          range_from_node(node),
          tags: [:active_support_declarative],
        )

        @response_builder.add(test_item)
      end

      #: ((Prism::ConstantPathNode | Prism::ConstantReadNode | Prism::ConstantPathTargetNode | Prism::CallNode | Prism::MissingNode) node) -> String
      def name_with_dynamic_reference(node)
        slice = node.slice
        slice.gsub(/((?<=::)|^)[a-z]\w*/, DYNAMIC_REFERENCE_MARKER)
      end
    end
  end
end
