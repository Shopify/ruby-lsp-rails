# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    module Support
      class SchemaTableLocationVisitorTest < ActiveSupport::TestCase
        # The cache is process wide, so don't leave entries behind for the other tests to pick up
        teardown do
          SchemaTableLocationVisitor.expire_cache
        end

        test ".find returns the location of a table defined with a string name" do
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

          location = SchemaTableLocationVisitor.find(source, "posts", base_prefix: "", base_suffix: "") #: as !nil

          assert_equal(6, location.start_line)
          assert_equal(8, location.end_line)
        end

        test ".find returns the location of a table defined with a symbol name" do
          source = <<~RUBY
            ActiveRecord::Schema[7.1].define(version: 1) do
              create_table :users, force: :cascade do |t|
                t.string "name"
              end

              create_table :posts, force: :cascade do |t|
                t.string "title"
              end
            end
          RUBY

          location = SchemaTableLocationVisitor.find(source, "posts", base_prefix: "", base_suffix: "") #: as !nil

          assert_equal(6, location.start_line)
          assert_equal(8, location.end_line)
        end

        test ".find does not traverse into a `create_table` block" do
          source = <<~RUBY
            create_table "users", force: :cascade do |t|
              t.string "name"
            end
          RUBY

          SchemaTableLocationVisitor.any_instance.expects(:visit_string_node).never

          assert(SchemaTableLocationVisitor.find(source, "users", base_prefix: "", base_suffix: ""))
        end

        test ".find removes ActiveRecord::Base prefix and suffix" do
          source = <<~RUBY
            ActiveRecord::Schema[7.1].define(version: 1) do
              create_table "users", force: :cascade do |t|
                t.string "name"
              end
            end
          RUBY

          location = SchemaTableLocationVisitor.find(source, "base_users_base", base_prefix: "base_", base_suffix: "_base") #: as !nil

          assert_equal(2, location.start_line)
          assert_equal(4, location.end_line)
        end

        test ".find preserves the name when the ActiveRecord::Base prefix does not match" do
          source = <<~RUBY
            ActiveRecord::Schema[7.1].define(version: 1) do
              create_table "users", force: :cascade do |t|
                t.string "name"
              end

              create_table "user_profiles_base", force: :cascade do |t|
                t.string "name"
              end
            end
          RUBY

          location = SchemaTableLocationVisitor.find(source, "user_profiles_base", base_prefix: "base_", base_suffix: "_base") #: as !nil

          assert_equal(6, location.start_line)
          assert_equal(8, location.end_line)
        end

        test ".find preserves the name when the ActiveRecord::Base suffix does not match" do
          source = <<~RUBY
            ActiveRecord::Schema[7.1].define(version: 1) do
              create_table "users", force: :cascade do |t|
                t.string "name"
              end

              create_table "base_user_profiles", force: :cascade do |t|
                t.string "name"
              end
            end
          RUBY

          location = SchemaTableLocationVisitor.find(source, "base_user_profiles", base_prefix: "base_", base_suffix: "_base") #: as !nil

          assert_equal(6, location.start_line)
          assert_equal(8, location.end_line)
        end

        test ".find returns nil if the table is not found" do
          assert_nil(SchemaTableLocationVisitor.find(schema_source, "non_existing_table", base_prefix: "", base_suffix: ""))
        end

        test ".find does not parse the same source again while it is cached" do
          assert(SchemaTableLocationVisitor.find(schema_source, "users", base_prefix: "", base_suffix: ""))

          Prism.expects(:parse).never

          assert(SchemaTableLocationVisitor.find(schema_source, "users", base_prefix: "", base_suffix: ""))
        end

        test ".expire_cache makes the next lookup parse the source again" do
          assert(SchemaTableLocationVisitor.find(schema_source, "users", base_prefix: "", base_suffix: ""))

          SchemaTableLocationVisitor.expire_cache

          # Parsed up front because the stub below counts every call, including the one setting it up
          empty_result = Prism.parse("")
          Prism.expects(:parse).once.returns(empty_result)

          assert_nil(SchemaTableLocationVisitor.find(schema_source, "users", base_prefix: "", base_suffix: ""))
        end

        private

        def schema_source
          @schema_source ||= File.read("#{dummy_root}/db/schema.rb")
        end
      end
    end
  end
end
