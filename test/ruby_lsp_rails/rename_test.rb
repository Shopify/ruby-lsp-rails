# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class RenameTest < ActiveSupport::TestCase
      test "renames migration file to match new class name" do
        document_changes = collect_file_renames(
          "#{dummy_root}/db/migrate/20210901000000_create_foos.rb",
          "class CreateFoos < ActiveRecord::Migration[7.0]; end",
          "CreateFoos",
          "CreateBars",
        )

        assert_equal(1, document_changes.size)
        rename = document_changes.first
        assert_instance_of(Interface::RenameFile, rename)
        assert_equal(
          URI::Generic.from_path(path: "#{dummy_root}/db/migrate/20210901000000_create_foos.rb").to_s,
          rename.old_uri,
        )
        assert_equal(
          URI::Generic.from_path(path: "#{dummy_root}/db/migrate/20210901000000_create_bars.rb").to_s,
          rename.new_uri,
        )
      end

      test "does nothing for non-migration files" do
        document_changes = collect_file_renames(
          "#{dummy_root}/app/models/foo.rb",
          "class Foo < ApplicationRecord; end",
          "Foo",
          "Bar",
        )

        assert_empty(document_changes)
      end

      test "does nothing when file name does not match class name" do
        document_changes = collect_file_renames(
          "#{dummy_root}/db/migrate/20210901000000_something_else.rb",
          "class CreateFoos < ActiveRecord::Migration[7.0]; end",
          "CreateFoos",
          "CreateBars",
        )

        assert_empty(document_changes)
      end

      private

      def collect_file_renames(file_path, source, old_name, new_name)
        index = RubyIndexer::Index.new
        uri = URI::Generic.from_path(path: file_path)
        index.index_single(uri, source)

        document_changes = []
        Rename.new(index, old_name, new_name, document_changes)
        document_changes
      end
    end
  end
end
