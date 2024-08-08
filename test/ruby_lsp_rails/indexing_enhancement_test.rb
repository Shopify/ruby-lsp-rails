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
            index.register_enhancement(IndexingEnhancement.new)
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
    end
  end
end
