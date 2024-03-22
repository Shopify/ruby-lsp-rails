# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class HoverTest < ActiveSupport::TestCase
      setup do
        @message_queue = Thread::Queue.new

        # Build the Rails documents index ahead of time
        capture_io do
          Support::RailsDocumentClient.send(:search_index)
        end
      end

      teardown do
        @message_queue.close
      end

      test "hook returns model column information" do
        expected_response = {
          schema_file: "#{dummy_root}/db/schema.rb",
          columns: [
            ["id", "integer"],
            ["first_name", "string"],
            ["last_name", "string"],
            ["age", "integer"],
            ["created_at", "datetime"],
            ["updated_at", "datetime"],
          ],
        }

        RunnerClient.any_instance.stubs(model: expected_response)

        response = hover_on_source(<<~RUBY, { line: 3, character: 0 })
          class User < ApplicationRecord
          end

          User
        RUBY

        assert_equal(<<~CONTENT.chomp, response.contents.value)
          ```ruby
          User
          ```

          **Definitions**: [fake.rb](file:///fake.rb#L1,1-2,4)
          [Schema](file://#{dummy_root}/db/schema.rb)


          **id**: integer

          **first_name**: string

          **last_name**: string

          **age**: integer

          **created_at**: datetime

          **updated_at**: datetime
        CONTENT
      end

      test "return column information for namespaced models" do
        expected_response = {
          schema_file: "#{dummy_root}/db/schema.rb",
          columns: [
            ["id", "integer"],
            ["first_name", "string"],
            ["last_name", "string"],
            ["age", "integer"],
            ["created_at", "datetime"],
            ["updated_at", "datetime"],
          ],
        }

        RunnerClient.any_instance.stubs(model: expected_response)

        response = hover_on_source(<<~RUBY, { line: 4, character: 6 })
          module Blog
            class User < ApplicationRecord
            end
          end

          Blog::User
        RUBY

        assert_equal(<<~CONTENT.chomp, response.contents.value)
          [Schema](file://#{dummy_root}/db/schema.rb)

          **id**: integer

          **first_name**: string

          **last_name**: string

          **age**: integer

          **created_at**: datetime

          **updated_at**: datetime
        CONTENT
      end

      test "handles `db/structure.sql` instead of `db/schema.rb`" do
        expected_response = {
          schema_file: "#{dummy_root}/db/structure.sql",
          columns: [],
        }

        RunnerClient.any_instance.stubs(model: expected_response)

        response = hover_on_source(<<~RUBY, { line: 3, character: 0 })
          class User < ApplicationRecord
          end

          User
        RUBY

        assert_includes(
          response.contents.value,
          "[Schema](file://#{dummy_root}/db/structure.sql)",
        )
      end

      test "handles neither `db/structure.sql` nor `db/schema.rb` being present" do
        expected_response = {
          schema_file: nil,
          columns: [],
        }

        RunnerClient.any_instance.stubs(model: expected_response)

        response = hover_on_source(<<~RUBY, { line: 3, character: 0 })
          class User < ApplicationRecord
          end

          User
        RUBY

        refute_match(/Schema/, response.contents.value)
      end

      test "shows documentation for routes DSLs" do
        value = hover_on_source("root 'projects#index'", { line: 0, character: 0 }).contents.value

        assert_match(/\[Rails Document: `ActionDispatch::Routing::Mapper::Resources#root`\]/, value)
        assert_match(%r{\(https://api\.rubyonrails\.org/.*\.html#method-i-root\)}, value)
      end

      test "shows documentation for controller DSLs" do
        value = hover_on_source("before_action :foo", { line: 0, character: 0 }).contents.value

        assert_match(/\[Rails Document: `AbstractController::Callbacks::ClassMethods#before_action`\]/, value)
        assert_match(%r{\(https://api\.rubyonrails\.org/.*\.html#method-i-before_action\)}, value)
      end

      test "shows documentation for job DSLs" do
        value = hover_on_source("queue_as :default", { line: 0, character: 0 }).contents.value

        assert_match(/\[Rails Document: `ActiveJob::QueueName::ClassMethods#queue_as`\]/, value)
        assert_match(%r{\(https://api\.rubyonrails\.org/.*\.html#method-i-queue_as\)}, value)
      end

      test "shows documentation for model DSLs" do
        value = hover_on_source("validate :foo", { line: 0, character: 0 }).contents.value

        assert_match(/\[Rails Document: `ActiveModel::EachValidator#validate`\]/, value)
        assert_match(%r{\(https://api\.rubyonrails\.org/.*\.html#method-i-validate\)}, value)
      end

      test "shows documentation for Rails constants" do
        value = hover_on_source(<<~RUBY, { line: 2, character: 14 }).contents.value
          class ActiveRecord::Base
          end
          ActiveRecord::Base
        RUBY

        assert_match(/\[Rails Document: `ActiveRecord::Base`\]/, value)
        assert_match(%r{\(https://api\.rubyonrails\.org/.*Base\.html\)}, value)
      end

      private

      def hover_on_source(source, position)
        with_server(source) do |server, uri|
          server.process_message(
            id: 1,
            method: "textDocument/hover",
            params: { textDocument: { uri: uri }, position: position },
          )

          server.pop_response.response
        end
      end
    end
  end
end
