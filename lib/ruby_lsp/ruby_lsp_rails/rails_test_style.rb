# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class RailsTestStyle < Listeners::TestDiscovery
      BASE_COMMAND = "#{RbConfig.ruby} bin/rails test" #: String

      class << self
        #: (Array[Hash[Symbol, untyped]]) -> Array[String]
        def resolve_test_commands(items)
          commands = []
          queue = items.dup

          full_files = []

          until queue.empty?
            item = queue.shift #: as !nil
            tags = Set.new(item[:tags])
            next unless tags.include?("framework:rails")

            children = item[:children]
            uri = URI(item[:uri])
            path = uri.full_path
            next unless path

            if tags.include?("test_dir")
              if children.empty?
                full_files.concat(Dir.glob(
                  "#{path}/**/{*_test,test_*}.rb",
                  File::Constants::FNM_EXTGLOB | File::Constants::FNM_PATHNAME,
                ))
              end
            elsif tags.include?("test_file")
              full_files << path if children.empty?
            elsif tags.include?("test_group")
              commands << "#{BASE_COMMAND} #{path} --name \"/#{Shellwords.escape(item[:id])}(#|::)/\""
            else
              full_files << "#{path}:#{item.dig(:range, :start, :line) + 1}"
            end

            queue.concat(children)
          end

          unless full_files.empty?
            commands << "#{BASE_COMMAND} #{full_files.join(" ")}"
          end

          commands
        end
      end

      #: (ResponseBuilders::TestCollection response_builder, GlobalState global_state, Prism::Dispatcher dispatcher, URI::Generic uri) -> void
      def initialize(response_builder, global_state, dispatcher, uri)
        @parent_stack = [response_builder] #: Array[(Requests::Support::TestItem | ResponseBuilders::TestCollection)?]
        super(response_builder, global_state, uri)

        register_events(
          dispatcher,
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

            last_test_group.add(test_item)
            @response_builder.add_code_lens(test_item)
            @parent_stack << test_item
          else
            @parent_stack << nil
          end
        end
      end

      #: (Prism::ClassNode node) -> void
      def on_class_node_leave(node)
        @parent_stack.pop
        super
      end

      #: (Prism::ModuleNode node) -> void
      def on_module_node_enter(node)
        @parent_stack << nil
        super
      end

      #: (Prism::ModuleNode node) -> void
      def on_module_node_leave(node)
        @parent_stack.pop
        super
      end

      #: (Prism::CallNode node) -> void
      def on_call_node_enter(node)
        return unless node.name == :test
        return unless node.block

        arguments = node.arguments&.arguments
        first_arg = arguments&.first
        return unless first_arg.is_a?(Prism::StringNode)

        test_name = first_arg.unescaped
        test_name = "<empty test name>" if test_name.empty?

        # Rails' `test "foo bar"` helper defines a method `def test_foo_bar`. We normalize test names
        # the same way (spaces to underscores, prefix with `test_`) to match the actual method names
        # Rails uses at runtime, ensuring proper test discovery and execution.
        rails_normalized_name = "test_#{test_name.gsub(/\s+/, "_")}"

        add_test_item(node, rails_normalized_name)
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
        parent = @parent_stack.last
        return unless parent.is_a?(Requests::Support::TestItem)

        example_item = Requests::Support::TestItem.new(
          "#{parent.id}##{test_name}",
          test_name,
          @uri,
          range_from_node(node),
          framework: :rails,
        )
        parent.add(example_item)
        @response_builder.add_code_lens(example_item)
      end

      #: -> (Requests::Support::TestItem | ResponseBuilders::TestCollection)
      def last_test_group
        index = @parent_stack.rindex { |i| i } #: as !nil
        @parent_stack[index] #: as Requests::Support::TestItem | ResponseBuilders::TestCollection
      end
    end
  end
end
