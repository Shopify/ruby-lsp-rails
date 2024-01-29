# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class SchemaCollector < Prism::Visitor
      extend T::Sig

      sig { returns(T::Hash[String, Prism::Location]) }
      attr_reader :tables

      sig { params(project_root: Pathname).void }
      def initialize(project_root)
        super()

        @tables = T.let({}, T::Hash[String, Prism::Location])
        @schema_path = T.let(project_root.join("db", "schema.rb").to_s, String)
      end

      sig { void }
      def parse_schema
        parse_result = Prism.parse_file(@schema_path)
        parse_result.value.accept(self)
      end

      sig { params(node: Prism::CallNode).void }
      def visit_call_node(node)
        if node.message == "create_table"
          first_argument = node.arguments&.arguments&.first

          if first_argument&.is_a?(Prism::StringNode)
            @tables[first_argument.content] = node.location
          end
        end

        super
      end
    end
  end
end
