# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class SchemaCollector < Prism::Visitor
      extend T::Sig
      extend T::Generic

      sig { returns(T::Hash[String, Prism::Location]) }
      attr_reader :tables

      sig { void }
      def initialize
        @tables = {}

        super
      end

      sig { void }
      def parse_schema
        parse_result = Prism::parse_file(schema_path)
        return unless parse_result.success?

        parse_result.value.accept(self)
      end

      sig { params(node: Prism::CallNode).void }
      def visit_call_node(node)
        if node.message == 'create_table'
          first_argument = node.arguments&.arguments&.first

          if first_argument&.is_a?(Prism::StringNode)
            @tables[first_argument.content] = node.location
          end
        end

        super
      end

      private

      sig { returns(String) }
      def schema_path
        project_root = T.let(
          Bundler.with_unbundled_env { Bundler.default_gemfile }.dirname,
          Pathname,
        )
        project_root.join('db', 'schema.rb').to_s
      end
    end
  end
end
