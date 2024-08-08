# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class IndexingEnhancement
      extend T::Sig
      include RubyIndexer::Enhancement

      sig do
        override.params(
          index: RubyIndexer::Index,
          owner: T.nilable(RubyIndexer::Entry::Namespace),
          node: Prism::CallNode,
          file_path: String,
        ).void
      end
      def on_call_node(index, owner, node, file_path)
        return unless owner

        name = node.name

        case name
        when :extend
          handle_concern_extend(index, owner, node)
        end
      end

      private

      sig do
        params(
          index: RubyIndexer::Index,
          owner: RubyIndexer::Entry::Namespace,
          node: Prism::CallNode,
        ).void
      end
      def handle_concern_extend(index, owner, node)
        arguments = node.arguments&.arguments
        return unless arguments

        arguments.each do |node|
          next unless node.is_a?(Prism::ConstantReadNode) || node.is_a?(Prism::ConstantPathNode)

          module_name = node.full_name
          next unless module_name == "ActiveSupport::Concern"

          index.register_included_hook(owner.name) do |index, base|
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
