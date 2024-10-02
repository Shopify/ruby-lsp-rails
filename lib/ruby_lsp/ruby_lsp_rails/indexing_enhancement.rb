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
        when :has_one, :has_many, :belongs_to, :has_and_belongs_to_many
          handle_association(index, owner, node, file_path)
        end
      end

      private

      sig do
        params(
          index: RubyIndexer::Index,
          owner: RubyIndexer::Entry::Namespace,
          node: Prism::CallNode,
          file_path: String,
        ).void
      end
      def handle_association(index, owner, node, file_path)
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

        # Reader
        index.add(RubyIndexer::Entry::Method.new(
          name,
          file_path,
          name_arg.location,
          name_arg.location,
          nil,
          index.configuration.encoding,
          [RubyIndexer::Entry::Signature.new([])],
          RubyIndexer::Entry::Visibility::PUBLIC,
          owner,
        ))

        # Writer
        index.add(RubyIndexer::Entry::Method.new(
          "#{name}=",
          file_path,
          name_arg.location,
          name_arg.location,
          nil,
          index.configuration.encoding,
          [RubyIndexer::Entry::Signature.new([RubyIndexer::Entry::RequiredParameter.new(name: name.to_sym)])],
          RubyIndexer::Entry::Visibility::PUBLIC,
          owner,
        ))
      end

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
