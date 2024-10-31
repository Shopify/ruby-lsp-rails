# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class IndexingEnhancement < RubyIndexer::Enhancement
      extend T::Sig

      sig do
        override.params(
          owner: T.nilable(RubyIndexer::Entry::Namespace),
          node: Prism::CallNode,
          file_path: String,
          code_units_cache: T.any(
            T.proc.params(arg0: Integer).returns(Integer),
            Prism::CodeUnitsCache,
          ),
        ).void
      end
      def on_call_node_enter(owner, node, file_path, code_units_cache)
        return unless owner

        name = node.name

        case name
        when :extend
          handle_concern_extend(owner, node)
        when :has_one, :has_many, :belongs_to, :has_and_belongs_to_many
          handle_association(owner, node, file_path, code_units_cache)
        end
      end

      private

      sig do
        params(
          owner: RubyIndexer::Entry::Namespace,
          node: Prism::CallNode,
          file_path: String,
          code_units_cache: T.any(
            T.proc.params(arg0: Integer).returns(Integer),
            Prism::CodeUnitsCache,
          ),
        ).void
      end
      def handle_association(owner, node, file_path, code_units_cache)
        arguments = node.arguments&.arguments
        return unless arguments

        name_arg = arguments.first

        name = case name_arg
        when Prism::StringNode
          name_arg.content
        when Prism::SymbolNode
          name_arg.value
        end

        return unless name

        loc = RubyIndexer::Location.from_prism_location(name_arg.location, code_units_cache)

        # Reader
        @index.add(RubyIndexer::Entry::Method.new(
          name,
          file_path,
          loc,
          loc,
          nil,
          [RubyIndexer::Entry::Signature.new([])],
          RubyIndexer::Entry::Visibility::PUBLIC,
          owner,
        ))

        # Writer
        @index.add(RubyIndexer::Entry::Method.new(
          "#{name}=",
          file_path,
          loc,
          loc,
          nil,
          [RubyIndexer::Entry::Signature.new([RubyIndexer::Entry::RequiredParameter.new(name: name.to_sym)])],
          RubyIndexer::Entry::Visibility::PUBLIC,
          owner,
        ))
      end

      sig do
        params(
          owner: RubyIndexer::Entry::Namespace,
          node: Prism::CallNode,
        ).void
      end
      def handle_concern_extend(owner, node)
        arguments = node.arguments&.arguments
        return unless arguments

        arguments.each do |node|
          next unless node.is_a?(Prism::ConstantReadNode) || node.is_a?(Prism::ConstantPathNode)

          module_name = node.full_name
          next unless module_name == "ActiveSupport::Concern"

          @index.register_included_hook(owner.name) do |index, base|
            class_methods_name = "#{owner.name}::ClassMethods"

            if index.indexed?(class_methods_name)
              singleton = index.existing_or_new_singleton_class(base.name)
              singleton.mixin_operations << RubyIndexer::Entry::Include.new(class_methods_name)
            end
          end
        rescue Prism::ConstantPathNode::DynamicPartsInConstantPathError,
               Prism::ConstantPathNode::MissingNodesInConstantPathError
          # Do nothing
        end
      end
    end
  end
end
