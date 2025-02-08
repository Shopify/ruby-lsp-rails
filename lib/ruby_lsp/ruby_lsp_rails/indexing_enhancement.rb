# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class IndexingEnhancement < RubyIndexer::Enhancement
      extend T::Sig

      sig { params(listener: RubyIndexer::DeclarationListener).void }
      def initialize(listener)
        super

        @discovered_concerns = T.let([], T::Array[String])
      end

      sig { override.params(call_node: Prism::CallNode).void }
      def on_call_node_enter(call_node)
        owner = @listener.current_owner
        return unless owner

        case call_node.name
        when :extend
          handle_concern_extend(owner, call_node)
        when :has_one, :has_many, :belongs_to, :has_and_belongs_to_many
          handle_association(owner, call_node)
        # for `class_methods do` blocks within concerns
        when :class_methods
          handle_class_methods(owner, call_node)
        end
      end

      sig { override.params(call_node: Prism::CallNode).void }
      def on_call_node_leave(call_node)
        if call_node.name == :class_methods && call_node.block
          @listener.pop_namespace_stack
        end
      end

      private

      sig { params(owner: RubyIndexer::Entry::Namespace, call_node: Prism::CallNode).void }
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

          @discovered_concerns << owner.name

          @listener.register_included_hook do |index, base|
            class_methods_name = "#{owner.name}::ClassMethods"

            singleton = index.existing_or_new_singleton_class(base.name)

            if index.indexed?(class_methods_name)
              singleton.mixin_operations << RubyIndexer::Entry::Include.new(class_methods_name)
            end

            if @discovered_concerns.include?(owner.name)
              owner.mixin_operations.each do |operation|
                resolved_module = index.resolve(operation.module_name, base.nesting)
                next unless resolved_module

                name = T.must(resolved_module.first).name
                module_name = "#{name}::ClassMethods"
                next unless @discovered_concerns.include?(name) && index.indexed?(module_name)

                case operation
                when RubyIndexer::Entry::Include
                  singleton.mixin_operations << RubyIndexer::Entry::Include.new(module_name)
                when RubyIndexer::Entry::Prepend
                  singleton.mixin_operations.unshift(RubyIndexer::Entry::Include.new(module_name))
                end
              end
            end
          end
        rescue Prism::ConstantPathNode::DynamicPartsInConstantPathError,
               Prism::ConstantPathNode::MissingNodesInConstantPathError
          # Do nothing
        end
      end

      sig { params(owner: RubyIndexer::Entry::Namespace, call_node: Prism::CallNode).void }
      def handle_class_methods(owner, call_node)
        return unless call_node.block

        @listener.add_module("ClassMethods", call_node.location, call_node.location)
      end
    end
  end
end
