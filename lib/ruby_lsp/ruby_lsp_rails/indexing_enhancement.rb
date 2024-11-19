# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class IndexingEnhancement < RubyIndexer::Enhancement
      extend T::Sig

      sig { params(listener: RubyIndexer::DeclarationListener).void }
      def initialize(listener)
        super
        # We need this to prevent Sorbet from complaining that @listener is undeclared
        @listener = listener
      end

      sig do
        override.params(
          call_node: Prism::CallNode,
        ).void
      end
      def on_call_node_enter(call_node)
        owner = @listener.current_owner
        return unless owner

        case call_node.name
        when :extend
          handle_concern_extend(owner, call_node)
        when :has_one, :has_many, :belongs_to, :has_and_belongs_to_many
          handle_association(owner, call_node)
        end
      end

      private

      sig do
        params(
          owner: RubyIndexer::Entry::Namespace,
          call_node: Prism::CallNode,
        ).void
      end
      def handle_association(owner, call_node)
        arguments = call_node.arguments&.arguments
        return unless arguments

        name_arg = arguments.first

        name = case name_arg
        when Prism::StringNode
          name_arg.content
        when Prism::SymbolNode
          name_arg.value
        end

        return unless name

        loc = name_arg.location

        # Reader
        reader_signatures = [RubyIndexer::Entry::Signature.new([])]
        @listener.add_method(name, loc, reader_signatures)

        # Writer
        writer_signatures = [
          RubyIndexer::Entry::Signature.new([RubyIndexer::Entry::RequiredParameter.new(name: name.to_sym)]),
        ]
        @listener.add_method("#{name}=", loc, writer_signatures)
      end

      sig { params(owner: RubyIndexer::Entry::Namespace, call_node: Prism::CallNode).void }
      def handle_concern_extend(owner, call_node)
        arguments = call_node.arguments&.arguments
        return unless arguments

        arguments.each do |node|
          next unless node.is_a?(Prism::ConstantReadNode) || node.is_a?(Prism::ConstantPathNode)

          module_name = node.full_name
          next unless module_name == "ActiveSupport::Concern"

          @listener.register_included_hook do |index, base|
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
