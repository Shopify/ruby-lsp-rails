# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    module Support
      class SchemaTableLocationVisitor < Prism::Visitor
        class << self
          #: (String schema_file, String table_name) -> Prism::Location?
          def find(schema_file, table_name)
            table_locations(schema_file)[table_name]
          end

          #: -> void
          def expire_cache
            @cache.clear
          end

          private

          #: (String schema_file) -> Hash[String, Prism::Location]
          def table_locations(schema_file)
            @cache[schema_file] ||= begin
              visitor = new
              Prism.parse(File.read(schema_file)).value.accept(visitor)
              visitor.tables
            end
          rescue Errno::ENOENT, Errno::EACCES
            {}
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
          if node.message == "create_table"
            first_argument = node.arguments&.arguments&.first

            name = case first_argument
            when Prism::StringNode
              first_argument.unescaped
            when Prism::SymbolNode
              first_argument.unescaped
            end

            @tables[name] = node.location if name
          end

          super
        end
      end
    end
  end
end
