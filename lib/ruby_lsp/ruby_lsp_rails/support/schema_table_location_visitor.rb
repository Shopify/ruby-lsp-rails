# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    module Support
      class SchemaTableLocationVisitor < Prism::Visitor
        class << self
          #: (String source, String table_name) -> Prism::Location?
          def find(source, table_name)
            table_locations(source)[table_name]
          end

          #: -> void
          def expire_cache
            @cache.clear
          end

          private

          #: (String source) -> Hash[String, Prism::Location]
          def table_locations(source)
            @cache[source] ||= begin
              visitor = new
              Prism.parse(source).value.accept(visitor)
              visitor.tables
            end
          end
        end

        @cache = {} #: Hash[String, Hash[String, Prism::Location]]

        #: -> void
        def initialize
          super
          @tables = {} #: Hash[String, Prism::Location]
        end

        #: Hash[String, Prism::Location]
        attr_reader :tables

        #: (Prism::CallNode node) -> void
        def visit_call_node(node)
          unless node.message == "create_table"
            super
            return
          end

          first_argument = node.arguments&.arguments&.first

          name = case first_argument
          when Prism::StringNode
            first_argument.unescaped
          when Prism::SymbolNode
            first_argument.unescaped
          end

          @tables[name] = node.location if name
        end
      end
    end
  end
end
