# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class DefinitionTest < ActiveSupport::TestCase
      test "recognizes model callback with multiple symbol arguments" do
        source = <<~RUBY
          # typed: false

          class TestModel
            before_create :foo, :baz
            def foo; end
            def baz; end
          end
        RUBY
        response = generate_definitions_for_source(source, { line: 3, character: 18 })
        assert_equal(1, response.size)

        assert_equal("file:///fake.rb", response[0].uri)
        assert_equal(4, response[0].range.start.line)
        assert_equal(2, response[0].range.start.character)
        assert_equal(4, response[0].range.end.line)
        assert_equal(14, response[0].range.end.character)

        response = generate_definitions_for_source(source, { line: 3, character: 24 })
        assert_equal(1, response.size)
        assert_equal("file:///fake.rb", response[0].uri)
        assert_equal(5, response[0].range.start.line)
        assert_equal(2, response[0].range.start.character)
        assert_equal(5, response[0].range.end.line)
        assert_equal(14, response[0].range.end.character)
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
        source = <<~RUBY
          # typed: false

          class TestJob
            before_perform :foo, "baz"

            def foo; end
            def baz; end
          end
        RUBY
        response = generate_definitions_for_source(source, { line: 3, character: 20 })

        assert_equal(1, response.size)
        assert_equal("file:///fake.rb", response[0].uri)
        assert_equal(5, response[0].range.start.line)
        assert_equal(2, response[0].range.start.character)
        assert_equal(5, response[0].range.end.line)
        assert_equal(14, response[0].range.end.character)

        response = generate_definitions_for_source(source, { line: 3, character: 25 })

        assert_equal(1, response.size)
        assert_equal("file:///fake.rb", response[0].uri)
        assert_equal(6, response[0].range.start.line)
        assert_equal(2, response[0].range.start.character)
        assert_equal(6, response[0].range.end.line)
        assert_equal(14, response[0].range.end.character)
      end

      test "recognizes job callback with symbol argument and conditional" do
        source = <<~RUBY
          # typed: false

          class TestJob
            before_create :foo, -> () {}, if: :bar?

            def foo; end
            def bar?; end
          end
        RUBY

        response = generate_definitions_for_source(source, { line: 3, character: 18 })

        assert_equal(1, response.size)
        assert_equal("file:///fake.rb", response[0].uri)
        assert_equal(5, response[0].range.start.line)
        assert_equal(2, response[0].range.start.character)
        assert_equal(5, response[0].range.end.line)
        assert_equal(14, response[0].range.end.character)

        response = generate_definitions_for_source(source, { line: 3, character: 38 })

        assert_equal(1, response.size)
        assert_equal("file:///fake.rb", response[0].uri)
        assert_equal(6, response[0].range.start.line)
        assert_equal(2, response[0].range.start.character)
        assert_equal(6, response[0].range.end.line)
        assert_equal(15, response[0].range.end.character)
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

      test "recognizes validate method with symbol argument" do
        response = generate_definitions_for_source(<<~RUBY, { line: 1, character: 12 })
          class FooModel < ApplicationRecord
            validate :custom_validation

          private
            def custom_validation; end
          end
        RUBY

        assert_equal(1, response.size)

        response = response.first

        assert_equal("file:///fake.rb", response.uri)
        assert_equal(4, response.range.start.line)
        assert_equal(2, response.range.start.character)
        assert_equal(4, response.range.end.line)
        assert_equal(28, response.range.end.character)
      end

      test "recognizes validate method with multiple symbol arguments" do
        source = <<~RUBY
          class FooModel < ApplicationRecord
            validate :first_validation, :second_validation

          private
            def first_validation; end
            def second_validation; end
          end
        RUBY

        response = generate_definitions_for_source(source, { line: 1, character: 12 })

        assert_equal(1, response.size)
        response = response.first
        assert_equal("file:///fake.rb", response.uri)
        assert_equal(4, response.range.start.line)
        assert_equal(2, response.range.start.character)
        assert_equal(4, response.range.end.line)
        assert_equal(27, response.range.end.character)

        response = generate_definitions_for_source(source, { line: 1, character: 33 })

        assert_equal(1, response.size)
        response = response.first
        assert_equal("file:///fake.rb", response.uri)
        assert_equal(5, response.range.start.line)
        assert_equal(2, response.range.start.character)
        assert_equal(5, response.range.end.line)
        assert_equal(28, response.range.end.character)
      end

      test "recognizes validates attribute symbol with multiple attributes and conditional options" do
        source = <<~RUBY
          class FooModel < ApplicationRecord
            validates :email, :name, presence: true, if: :foo?, unless: :bar?

            def email; end
            def name; end
            def foo?; end
            def bar?; end
          end
        RUBY

        response = generate_definitions_for_source(source, { line: 1, character: 13 })

        assert_equal(1, response.size)
        response = response.first
        assert_equal("file:///fake.rb", response.uri)
        assert_equal(3, response.range.start.line)
        assert_equal(2, response.range.start.character)
        assert_equal(3, response.range.end.line)
        assert_equal(16, response.range.end.character)

        response = generate_definitions_for_source(source, { line: 1, character: 21 })

        assert_equal(1, response.size)
        response = response.first
        assert_equal("file:///fake.rb", response.uri)
        assert_equal(4, response.range.start.line)
        assert_equal(2, response.range.start.character)
        assert_equal(4, response.range.end.line)
        assert_equal(15, response.range.end.character)

        response = generate_definitions_for_source(source, { line: 1, character: 50 })
        assert_equal(1, response.size)
        response = response.first
        assert_equal("file:///fake.rb", response.uri)
        assert_equal(5, response.range.start.line)
        assert_equal(2, response.range.start.character)
        assert_equal(5, response.range.end.line)
        assert_equal(15, response.range.end.character)

        response = generate_definitions_for_source(source, { line: 1, character: 65 })
        assert_equal(1, response.size)
        response = response.first
        assert_equal("file:///fake.rb", response.uri)
        assert_equal(6, response.range.start.line)
        assert_equal(2, response.range.start.character)
        assert_equal(6, response.range.end.line)
        assert_equal(15, response.range.end.character)
      end

      test "does not find definition for validates attribute symbol without getter method" do
        response = generate_definitions_for_source(<<~RUBY, { line: 1, character: 12 })
          class FooModel < ApplicationRecord
            validates :email, presence: true
            # No email method defined
          end
        RUBY

        assert_empty(response)
      end

      test "recognizes validates_each attribute symbols that have getter methods" do
        source = <<~RUBY
          class FooModel < ApplicationRecord
            validates_each :email, :name do |record, attr, value|
              record.errors.add(attr, "is invalid") if value.blank?
            end

            def email; end
            def name; end
          end
        RUBY

        response = generate_definitions_for_source(source, { line: 1, character: 17 })

        assert_equal(1, response.size)
        response = response.first
        assert_equal("file:///fake.rb", response.uri)
        assert_equal(5, response.range.start.line)
        assert_equal(2, response.range.start.character)
        assert_equal(5, response.range.end.line)
        assert_equal(16, response.range.end.character)

        response = generate_definitions_for_source(source, { line: 1, character: 26 })

        assert_equal(1, response.size)
        response = response.first
        assert_equal("file:///fake.rb", response.uri)
        assert_equal(6, response.range.start.line)
        assert_equal(2, response.range.start.character)
        assert_equal(6, response.range.end.line)
        assert_equal(15, response.range.end.character)
      end

      test "finds the controller action definition when only one controller matches" do
        source = <<~RUBY
          Rails.application.routes.draw do
            # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
            resources :users do
              get :archive, on: :collection, to: "users#archive"
              get :unarchive, on: :collection, to: "users#unarchive"
            end

            scope module: "admin" do
              resources :users do
                get :archive, on: :collection, to: "users#archive"
              end
            end
          end
        RUBY

        response = generate_definitions_for_source(source, { line: 4, character: 45 }, uri: URI("file:///config/routes.rb"))

        assert_equal(1, response.size)

        location = response.first

        expected_path = File.expand_path("test/dummy/app/controllers/users_controller.rb")
        assert_equal("file://#{expected_path}", location.uri)
        assert_equal(7, location.range.start.line)
        assert_equal(7, location.range.end.line)
      end

      test "finds all matching controller actions when multiple controllers exist in different namespaces" do
        source = <<~RUBY
          Rails.application.routes.draw do
            # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
            resources :users do
              get :archive, on: :collection, to: "users#archive"
              get :unarchive, on: :collection, to: "users#unarchive"
            end

            scope module: "admin" do
              resources :users do
                get :archive, on: :collection, to: "users#archive"
              end
            end
          end
        RUBY

        response = generate_definitions_for_source(source, { line: 3, character: 45 }, uri: URI("file:///config/routes.rb"))

        assert_equal(2, response.size)

        location = response.first

        expected_path = File.expand_path("test/dummy/app/controllers/users_controller.rb")
        assert_equal("file://#{expected_path}", location.uri)
        assert_equal(5, location.range.start.line)
        assert_equal(5, location.range.end.line)

        location = response.second

        expected_path = File.expand_path("test/dummy/app/controllers/admin/users_controller.rb")
        assert_equal("file://#{expected_path}", location.uri)
        assert_equal(6, location.range.start.line)
        assert_equal(6, location.range.end.line)
      end

      private

      def generate_definitions_for_source(source, position, uri: nil)
        with_server(source, *[uri].compact) do |server, uri|
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
