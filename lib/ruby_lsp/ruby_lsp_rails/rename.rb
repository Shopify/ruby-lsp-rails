# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class Rename
      #: (RubyIndexer::Index index, String fully_qualified_name, String new_name, Array[(Interface::RenameFile | Interface::TextDocumentEdit)] document_changes) -> void
      def initialize(index, fully_qualified_name, new_name, document_changes)
        index[fully_qualified_name]&.each do |entry|
          file_path = entry.uri.full_path
          next unless file_path

          next unless file_path.include?("/db/migrate/")

          old_file_name = entry.file_name
          old_snake = file_from_constant_name(entry.name.split("::").last)

          next unless old_file_name.match?(/\A\d+_#{Regexp.escape(old_snake)}\.rb\z/)

          timestamp_prefix = old_file_name.delete_suffix("_#{old_snake}.rb")
          new_snake = file_from_constant_name(new_name.split("::").last)

          new_uri = URI::Generic.from_path(
            path: File.join(File.dirname(file_path), "#{timestamp_prefix}_#{new_snake}.rb"),
          ).to_s

          document_changes << Interface::RenameFile.new(kind: "rename", old_uri: entry.uri.to_s, new_uri: new_uri)
        end
      end

      private

      #: (String constant_name) -> String
      def file_from_constant_name(constant_name)
        constant_name
          .gsub(/([a-z])([A-Z])|([A-Z])([A-Z][a-z])/, '\1\3_\2\4')
          .downcase
      end
    end
  end
end
