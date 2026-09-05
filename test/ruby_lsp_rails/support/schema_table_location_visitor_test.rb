# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    module Support
      class SchemaTableLocationVisitorTest < ActiveSupport::TestCase
        test "collects the location of tables defined with a string name" do
          source = <<~RUBY
            ActiveRecord::Schema[7.1].define(version: 1) do
              create_table "users", force: :cascade do |t|
                t.string "name"
              end

              create_table "posts", force: :cascade do |t|
                t.string "title"
              end
            end
          RUBY

          visitor = SchemaTableLocationVisitor.new
          Prism.parse(source).value.accept(visitor)

          posts_location = visitor.tables.fetch("posts")
          assert_equal(6, posts_location.start_line)
          assert_equal(8, posts_location.end_line)
        end

        test "collects the location of tables defined with a symbol name" do
          source = <<~RUBY
            ActiveRecord::Schema[7.1].define(version: 1) do
              create_table :users, force: :cascade do |t|
                t.string "name"
              end
            end
          RUBY

          visitor = SchemaTableLocationVisitor.new
          Prism.parse(source).value.accept(visitor)

          assert_equal(2, visitor.tables.fetch("users").start_line)
        end

        test ".find returns nil if the table is not found" do
          Tempfile.create(["schema", ".rb"]) do |file|
            file.write(<<~RUBY)
              ActiveRecord::Schema[7.1].define(version: 1) do
                create_table "users", force: :cascade do |t|
                  t.string "name"
                end
              end
            RUBY
            file.flush

            assert_nil(SchemaTableLocationVisitor.find(file.path, "non_existing_table"))
          end
        end

        test ".find caches results until the cache is expired" do
          Tempfile.create(["schema", ".rb"]) do |file|
            file.write(<<~RUBY)
              ActiveRecord::Schema[7.1].define(version: 1) do
                create_table "users", force: :cascade do |t|
                  t.string "name"
                end
              end
            RUBY
            file.flush

            location = SchemaTableLocationVisitor.find(file.path, "users") #: as !nil
            assert_equal(2, location.start_line)

            File.write(file.path, <<~RUBY)
              ActiveRecord::Schema[7.1].define(version: 1) do
              end
            RUBY

            assert(SchemaTableLocationVisitor.find(file.path, "users"))

            SchemaTableLocationVisitor.expire_cache
            assert_nil(SchemaTableLocationVisitor.find(file.path, "users"))
          end
        end

        test ".find returns nil if the schema file doesn't exist" do
          assert_nil(SchemaTableLocationVisitor.find("/nonexistent/schema.rb", "users"))
        end
      end
    end
  end
end
