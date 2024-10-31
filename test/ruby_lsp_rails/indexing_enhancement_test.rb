# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class IndexingEnhancementTest < ActiveSupport::TestCase
      class << self
        # For these tests, it's convenient to have the index fully populated with Rails information, but we don't have
        # to reindex on every single example or that will be too slow
        def populated_index
          @index ||= begin
            index = RubyIndexer::Index.new
            indexing_enhancement = IndexingEnhancement.new(index)
            index.register_enhancement(indexing_enhancement)
            index.index_all
            index
          end
        end
      end

      def setup
        @index = self.class.populated_index
      end

      test "ClassMethods module inside concerns are automatically extended" do
        @index.index_single(RubyIndexer::IndexablePath.new(nil, "/fake.rb"), <<~RUBY)
          class Post < ActiveRecord::Base
          end
        RUBY

        ancestors = @index.linearized_ancestors_of("Post::<Class:Post>")
        assert_includes(ancestors, "ActiveRecord::Associations::ClassMethods")
        assert_includes(ancestors, "ActiveRecord::Store::ClassMethods")
        assert_includes(ancestors, "ActiveRecord::AttributeMethods::ClassMethods")
      end

      test "associations" do
        @index.index_single(RubyIndexer::IndexablePath.new(nil, "/fake.rb"), <<~RUBY)
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
