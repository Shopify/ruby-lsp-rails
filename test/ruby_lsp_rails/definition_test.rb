# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class DefinitionTest < ActiveSupport::TestCase
      test "recognizes model callback with multiple symbol arguments" do
        response = generate_definitions_for_source(<<~RUBY, { line: 3, character: 18 })
          # typed: false

          class TestModel
            before_create :foo, :baz

            def foo; end
            def baz; end
          end
        RUBY

        assert_equal(2, response.size)

        assert_equal("file:///fake.rb", response[0].uri)
        assert_equal(5, response[0].range.start.line)
        assert_equal(2, response[0].range.start.character)
        assert_equal(5, response[0].range.end.line)
        assert_equal(14, response[0].range.end.character)

        assert_equal("file:///fake.rb", response[1].uri)
        assert_equal(6, response[1].range.start.line)
        assert_equal(2, response[1].range.start.character)
        assert_equal(6, response[1].range.end.line)
        assert_equal(14, response[1].range.end.character)
      end

      test "recognizes has_many model associations" do
        response = generate_definitions_for_source(<<~RUBY, { line: 3, character: 14 })
          # typed: false

          class Organization < ActiveRecord::Base
            has_many :memberships
          end
        RUBY

        assert_equal(1, response.size)

        assert_equal(
          URI::Generic.from_path(path: File.join(dummy_root, "app", "models", "membership.rb")).to_s,
          response[0].uri,
        )
        assert_equal(2, response[0].range.start.line)
        assert_equal(2, response[0].range.end.line)
      end

      test "recognizes belongs_to model associations" do
        response = generate_definitions_for_source(<<~RUBY, { line: 3, character: 14 })
          # typed: false

          class Membership < ActiveRecord::Base
            belongs_to :organization
          end
        RUBY

        assert_equal(1, response.size)

        assert_equal(
          URI::Generic.from_path(path: File.join(dummy_root, "app", "models", "organization.rb")).to_s,
          response[0].uri,
        )
        assert_equal(2, response[0].range.start.line)
        assert_equal(2, response[0].range.end.line)
      end

      test "recognizes has_one model associations" do
        response = generate_definitions_for_source(<<~RUBY, { line: 3, character: 11 })
          # typed: false

          class User < ActiveRecord::Base
            has_one :profile
          end
        RUBY

        assert_equal(1, response.size)

        assert_equal(
          URI::Generic.from_path(path: File.join(dummy_root, "app", "models", "profile.rb")).to_s,
          response[0].uri,
        )
        assert_equal(2, response[0].range.start.line)
        assert_equal(2, response[0].range.end.line)
      end

      test "recognizes has_and_belongs_to_many model associations" do
        response = generate_definitions_for_source(<<~RUBY, { line: 3, character: 27 })
          # typed: false

          class Profile < ActiveRecord::Base
            has_and_belongs_to_many :labels
          end
        RUBY

        assert_equal(1, response.size)

        assert_equal(
          URI::Generic.from_path(path: File.join(dummy_root, "app", "models", "label.rb")).to_s,
          response[0].uri,
        )
        assert_equal(2, response[0].range.start.line)
        assert_equal(2, response[0].range.end.line)
      end

      test "handles class_name argument for associations" do
        response = generate_definitions_for_source(<<~RUBY, { line: 3, character: 11 })
          # typed: false

          class User < ActiveRecord::Base
            has_one :location, class_name: "Country"
          end
        RUBY

        assert_equal(1, response.size)

        assert_equal(
          URI::Generic.from_path(path: File.join(dummy_root, "app", "models", "country.rb")).to_s,
          response[0].uri,
        )
        assert_equal(2, response[0].range.start.line)
        assert_equal(2, response[0].range.end.line)
      end

      test "recognizes controller callback with string argument" do
        response = generate_definitions_for_source(<<~RUBY, { line: 3, character: 17 })
          # typed: false

          class TestController
            before_action "foo"

            def foo; end
          end
        RUBY

        assert_equal(1, response.size)

        assert_equal("file:///fake.rb", response[0].uri)
        assert_equal(5, response[0].range.start.line)
        assert_equal(2, response[0].range.start.character)
        assert_equal(5, response[0].range.end.line)
        assert_equal(14, response[0].range.end.character)
      end

      test "recognizes job callback with string and symbol arguments" do
        response = generate_definitions_for_source(<<~RUBY, { line: 3, character: 18 })
          # typed: false

          class TestJob
            before_perform :foo, "baz"

            def foo; end
            def baz; end
          end
        RUBY

        assert_equal(2, response.size)

        assert_equal("file:///fake.rb", response[0].uri)
        assert_equal(5, response[0].range.start.line)
        assert_equal(2, response[0].range.start.character)
        assert_equal(5, response[0].range.end.line)
        assert_equal(14, response[0].range.end.character)

        assert_equal("file:///fake.rb", response[1].uri)
        assert_equal(6, response[1].range.start.line)
        assert_equal(2, response[1].range.start.character)
        assert_equal(6, response[1].range.end.line)
        assert_equal(14, response[1].range.end.character)
      end

      test "provides the definition of a route" do
        response = generate_definitions_for_source(<<~RUBY, { line: 0, character: 0 })
          users_path
        RUBY

        assert_equal(1, response.size)
        dummy_root = File.expand_path("../dummy", __dir__)
        assert_equal(
          URI::Generic.from_path(path: File.join(dummy_root, "config", "routes.rb")).to_s,
          response[0].uri,
        )
        assert_equal(4, response[0].range.start.line)
        assert_equal(4, response[0].range.end.line)
      end

      test "handles incomplete routes" do
        response = generate_definitions_for_source(<<~RUBY, { line: 0, character: 0 })
          _path
        RUBY

        assert_empty(response)
      end

      test "provides the definition of a custom route" do
        response = generate_definitions_for_source(<<~RUBY, { line: 0, character: 0 })
          archive_users_path
        RUBY

        assert_equal(1, response.size)
        dummy_root = File.expand_path("../dummy", __dir__)
        assert_equal(
          URI::Generic.from_path(path: File.join(dummy_root, "config", "routes.rb")).to_s,
          response[0].uri,
        )
        assert_equal(5, response[0].range.start.line)
        assert_equal(5, response[0].range.end.line)
      end

      test "ignored non-existing routes" do
        response = generate_definitions_for_source(<<~RUBY, { line: 0, character: 0 })
          invalid_path
        RUBY

        assert_empty(response)
      end

      test "recognizes mailbox before_processing callback" do
        response = generate_definitions_for_source(<<~RUBY, { line: 1, character: 20 })
          class FooMailbox < ApplicationMailbox
            before_processing :bar

            private
              def bar; end
          end
        RUBY

        assert_equal(1, response.size)

        response = response.first

        assert_equal("file:///fake.rb", response.uri)
        assert_equal(4, response.range.start.line)
        assert_equal(4, response.range.start.character)
        assert_equal(4, response.range.end.line)
        assert_equal(16, response.range.end.character)
      end

      test "recognizes mailbox around_processing callback" do
        response = generate_definitions_for_source(<<~RUBY, { line: 1, character: 20 })
          class FooMailbox < ApplicationMailbox
            around_processing :baz

            private
              def baz; end
          end
        RUBY

        assert_equal(1, response.size)

        response = response.first

        assert_equal("file:///fake.rb", response.uri)
        assert_equal(4, response.range.start.line)
        assert_equal(4, response.range.start.character)
        assert_equal(4, response.range.end.line)
        assert_equal(16, response.range.end.character)
      end

      test "recognizes mailbox after_processing callback" do
        response = generate_definitions_for_source(<<~RUBY, { line: 1, character: 20 })
          class FooMailbox < ApplicationMailbox
            after_processing :qux

            private
              def qux; end
          end
        RUBY

        assert_equal(1, response.size)

        response = response.first

        assert_equal("file:///fake.rb", response.uri)
        assert_equal(4, response.range.start.line)
        assert_equal(4, response.range.start.character)
        assert_equal(4, response.range.end.line)
        assert_equal(16, response.range.end.character)
      end

      private

      def generate_definitions_for_source(source, position)
        with_server(source) do |server, uri|
          sleep(0.1) while RubyLsp::Addon.addons.first.instance_variable_get(:@rails_runner_client).is_a?(NullClient)

          server.process_message(
            id: 1,
            method: "textDocument/definition",
            params: { textDocument: { uri: uri }, position: position },
          )

          result = pop_result(server)
          result.response
        end
      end
    end
  end
end
