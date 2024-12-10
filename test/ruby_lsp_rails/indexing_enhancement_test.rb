# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class IndexingEnhancementTest < ActiveSupport::TestCase
      class << self
        # For these tests, it's convenient to have the index fully populated with Rails information, but we don't have
        # to re-index on every single example or that will be too slow
        def populated_index
          @index ||= begin
            index = RubyIndexer::Index.new
            index.index_all
            index
          end
        end
      end

      def setup
        @index = self.class.populated_index
        @indexable_path = RubyIndexer::IndexablePath.new(nil, "/fake.rb")
      end

      def teardown
        # Prevent state leaking between tests
        @index.delete(@indexable_path)
        @index.instance_variable_set(:@ancestors, {})
      end

      test "ClassMethods module inside concerns are automatically extended" do
        @index.index_single(@indexable_path, <<~RUBY)
          module Verifiable
            extend ActiveSupport::Concern

            module ClassMethods
              def all_verified; end
            end
          end

          class Post
            include Verifiable
          end
        RUBY

        ancestors = @index.linearized_ancestors_of("Post::<Class:Post>")

        assert_includes(ancestors, "Verifiable::ClassMethods")
        refute_nil(@index.resolve_method("all_verified", "Post::<Class:Post>"))
      end

      test "class_methods blocks inside concerns are automatically extended via a ClassMethods module" do
        @index.index_single(@indexable_path, <<~RUBY)
          module Verifiable
            extend ActiveSupport::Concern

            class_methods do
              def all_verified; end
            end
          end

          class Post
            include Verifiable
          end
        RUBY

        ancestors = @index.linearized_ancestors_of("Post::<Class:Post>")

        assert_includes(ancestors, "Verifiable::ClassMethods")
        refute_nil(@index.resolve_method("all_verified", "Post::<Class:Post>"))
      end

      test "ignores `class_methods` calls without a block" do
        @index.index_single(@indexable_path, <<~RUBY)
          module Verifiable
            extend ActiveSupport::Concern

            class_methods
          end

          class Post
            include Verifiable
          end
        RUBY

        ancestors = @index.linearized_ancestors_of("Post::<Class:Post>")

        refute_includes(ancestors, "Verifiable::ClassMethods")
      end

      test "associations" do
        @index.index_single(@indexable_path, <<~RUBY)
          class Post < ActiveRecord::Base
            has_one :content
            belongs_to :author
            has_many :comments
            has_and_belongs_to_many :tags
          end
        RUBY

        assert_declaration_on_line("content", "Post", 2)
        assert_declaration_on_line("content=", "Post", 2)

        assert_declaration_on_line("author", "Post", 3)
        assert_declaration_on_line("author=", "Post", 3)

        assert_declaration_on_line("comments", "Post", 4)
        assert_declaration_on_line("comments=", "Post", 4)

        assert_declaration_on_line("tags", "Post", 5)
        assert_declaration_on_line("tags=", "Post", 5)
      end

      test "inherited class_methods" do
        @index.index_single(@indexable_path, <<~RUBY)
          module TheConcern
            extend ActiveSupport::Concern

            class_methods do
              def found_me; end
            end
          end

          module OtherConcern
            extend ActiveSupport::Concern
            include TheConcern
          end

          class Foo
            include OtherConcern
          end
        RUBY

        ancestors = @index.linearized_ancestors_of("Foo::<Class:Foo>")

        assert_includes(ancestors, "TheConcern::ClassMethods")
        refute_nil(@index.resolve_method("found_me", "Foo::<Class:Foo>"))
      end

      test "prepended and inherited class_methods" do
        @index.index_single(@indexable_path, <<~RUBY)
          module TheConcern
            extend ActiveSupport::Concern

            class_methods do
              def found_me; end
            end
          end

          module OtherConcern
            extend ActiveSupport::Concern
            prepend TheConcern

            module ClassMethods
              def other_found_me; end
            end
          end

          class Foo
            include OtherConcern
          end
        RUBY

        ancestors = @index.linearized_ancestors_of("Foo::<Class:Foo>")
        relevant_ancestors = ancestors[0..ancestors.index("BasicObject::<Class:BasicObject>")]

        assert_equal(
          [
            "Foo::<Class:Foo>",
            "OtherConcern::ClassMethods",
            "TheConcern::ClassMethods",
            "Object::<Class:Object>",
            "BasicObject::<Class:BasicObject>",
          ],
          relevant_ancestors,
        )
        refute_nil(@index.resolve_method("other_found_me", "Foo::<Class:Foo>"))
      end

      private

      def assert_declaration_on_line(method_name, class_name, line)
        association_entries = @index.resolve_method(method_name, class_name)
        refute_nil(association_entries)

        association = association_entries.first
        assert_equal(line, association.location.start_line)
      end
    end
  end
end
