# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class Completion
      include Requests::Support::Common

      # @override
      #: (RunnerClient client, ResponseBuilders::CollectionResponseBuilder[Interface::CompletionItem] response_builder, NodeContext node_context, RubyIndexer::Index index, Prism::Dispatcher dispatcher, URI::Generic uri) -> void
      def initialize(client, response_builder, node_context, index, dispatcher, uri)
        @response_builder = response_builder
        @client = client
        @node_context = node_context
        @index = index
        @path = uri.to_standardized_path #: String?
        dispatcher.register(
          self,
          :on_call_node_enter,
        )
      end

      #: (Prism::CallNode node) -> void
      def on_call_node_enter(node)
        call_node = @node_context.call_node
        receiver = call_node&.receiver

        if call_node&.name == :where && receiver.is_a?(Prism::ConstantReadNode)
          handle_active_record_where_completions(node: node, receiver: receiver)
        elsif active_record_migration?
          handle_active_record_migration_completions(node: node)
        end
      end

      private

      #: (node: Prism::CallNode, receiver: Prism::ConstantReadNode) -> void
      def handle_active_record_where_completions(node:, receiver:)
        resolved_class = @client.model(receiver.name.to_s)
        return if resolved_class.nil?

        arguments = @node_context.call_node&.arguments&.arguments
        indexed_call_node_args = {} #: Hash[String, Prism::Node]

        if arguments
          indexed_call_node_args = index_call_node_args(arguments: arguments)
          return if indexed_call_node_args.values.any? { |v| v == node }
        end

        range = range_from_location(node.location)

        resolved_class[:columns].each do |column|
          next unless column[0].start_with?(node.name.to_s)
          next if indexed_call_node_args.key?(column[0])

          @response_builder << Interface::CompletionItem.new(
            label: column[0],
            filter_text: column[0],
            label_details: Interface::CompletionItemLabelDetails.new(
              description: "Filter #{receiver.name} records by #{column[0]}",
            ),
            text_edit: Interface::TextEdit.new(range: range, new_text: "#{column[0]}: "),
            kind: Constant::CompletionItemKind::FIELD,
          )
        end
      end

      #: (node: Prism::CallNode) -> void
      def handle_active_record_migration_completions(node:)
        return if @path.nil?

        db_configs = @client.db_configs
        return if db_configs.nil?

        db_config = db_configs.values.find do |config|
          config[:migrations_paths].any? do |path|
            File.join(@client.rails_root, path) == File.dirname(@path)
          end
        end
        return if db_config.nil?

        range = range_from_location(node.location)

        @index.method_completion_candidates(node.message, db_config[:adapter_class]).each do |entry|
          next unless entry.public?

          entry_name = entry.name
          owner_name = entry.owner&.name

          label_details = Interface::CompletionItemLabelDetails.new(
            description: entry.file_name,
            detail: entry.decorated_parameters,
          )
          @response_builder << Interface::CompletionItem.new(
            label: entry_name,
            filter_text: entry_name,
            label_details: label_details,
            text_edit: Interface::TextEdit.new(range: range, new_text: entry_name),
            kind: Constant::CompletionItemKind::METHOD,
            data: {
              owner_name: owner_name,
            },
          )
        end
      end

      #: (arguments: Array[Prism::Node]) -> Hash[String, Prism::Node]
      def index_call_node_args(arguments:)
        indexed_call_node_args = {}
        arguments.each do |argument|
          next unless argument.is_a?(Prism::KeywordHashNode)

          argument.elements.each do |e|
            next unless e.is_a?(Prism::AssocNode)

            key = e.key
            if key.is_a?(Prism::SymbolNode)
              indexed_call_node_args[key.value] = e.value
            end
          end
        end
        indexed_call_node_args
      end

      # Checks that we're on instance level of a `ActiveRecord::Migration` subclass.
      #
      #: -> bool
      def active_record_migration?
        nesting_nodes = @node_context.instance_variable_get(:@nesting_nodes).reverse
        class_node = nesting_nodes.find { |node| node.is_a?(Prism::ClassNode) }
        return false unless class_node

        superclass = class_node.superclass
        return false unless superclass.is_a?(Prism::CallNode)

        receiver = superclass.receiver
        return false unless receiver.is_a?(Prism::ConstantPathNode)
        return false unless receiver.slice == "ActiveRecord::Migration"

        def_node = nesting_nodes.find { |n| n.is_a?(Prism::DefNode) }
        return false if def_node.receiver

        true
      end

    end
  end
end
