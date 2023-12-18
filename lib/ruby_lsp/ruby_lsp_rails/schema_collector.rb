class SchemaCollector < Prism::Visitor
  attr_reader :tables

  def initialize
    @tables = {}

    super
  end

  def visit_call_node(node)
    return if node.block.nil?

    node.block.body.child_nodes.each do |child_node|
      next unless child_node.is_a?(Prism::CallNode)
      next unless child_node.name == :create_table

      table_name = child_node.arguments.child_nodes.first.content
      @tables[table_name.classify] = child_node.location
    end
  end
end
