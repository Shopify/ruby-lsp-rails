# typed: strict
# frozen_string_literal: true

module RailsRubyLsp
  class Hover < ::RubyLsp::Extensions::Hover
    class << self
      extend T::Sig

      sig { override.params(target: SyntaxTree::Node).returns(T.nilable(String)) }
      def run(target)
        case target
        when SyntaxTree::Const
          model = RailsClient.instance.model(target.value)
          return if model.nil?

          schema_file = File.join(RailsClient.instance.root, "db", "schema.rb")
          content = +""
          content << "[Schema](file://#{schema_file})\n\n" if File.exist?(schema_file)
          content << model[:columns].map { |name, type| "**#{name}** | #{type}\n" }.join("\n")
          content
        end
      end
    end
  end
end
