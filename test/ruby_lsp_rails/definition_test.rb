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

      test "recognizes render calls" do
        FileUtils.touch("#{dummy_root}/app/views/users/_partial.html.erb")

        uri = Kernel.URI("file://#{dummy_root}/app/views/users/render.html.erb")
        source = <<~ERB
          <%= render "partial" %>
          <%= render "users/partial" %>
          <%= render partial: "partial" %>
          <%= render layout: "partial" %>
          <%= render spacer_template: "partial" %>
          <%= render template: "users/index" %>
        ERB

        with_ready_server(source, uri) do |server|
          response = text_document_definition(server, { line: 0, character: 12 }, uri)
          assert_equal("file://#{dummy_root}/app/views/users/_partial.html.erb", response.first.uri)

          response = text_document_definition(server, { line: 1, character: 12 }, uri)
          assert_equal("file://#{dummy_root}/app/views/users/_partial.html.erb", response.first.uri)

          response = text_document_definition(server, { line: 2, character: 21 }, uri)
          assert_equal("file://#{dummy_root}/app/views/users/_partial.html.erb", response.first.uri)

          response = text_document_definition(server, { line: 3, character: 20 }, uri)
          assert_equal("file://#{dummy_root}/app/views/users/_partial.html.erb", response.first.uri)

          response = text_document_definition(server, { line: 4, character: 31 }, uri)
          assert_equal("file://#{dummy_root}/app/views/users/_partial.html.erb", response.first.uri)

          response = text_document_definition(server, { line: 5, character: 23 }, uri)
          assert_equal("file://#{dummy_root}/app/views/users/index.html.erb", response.first.uri)
        end
      ensure
        FileUtils.rm("#{dummy_root}/app/views/users/_partial.html.erb")
      end

      test "handles custom view paths" do
        FileUtils.mkdir_p("#{dummy_root}/app/custom/views/admin")
        FileUtils.touch("#{dummy_root}/app/custom/views/admin/_partial.html.erb")
        File.write("#{dummy_root}/app/controllers/admin_controller.rb", <<~RUBY)
          class AdminController < ApplicationController
            prepend_view_path "#{dummy_root}/app/custom/views"
          end
        RUBY

        uri = Kernel.URI("file://#{dummy_root}/app/custom/views/admin/render.html.erb")
        source = <<~ERB
          <%= render "partial" %>
        ERB

        response = generate_definitions_for_source(source, { line: 0, character: 12 }, uri)
        assert_equal("file://#{dummy_root}/app/custom/views/admin/_partial.html.erb", response.first.uri)
      ensure
        FileUtils.rm_r("#{dummy_root}/app/custom/views/admin")
        FileUtils.rm("#{dummy_root}/app/controllers/admin_controller.rb")
      end

      test "handles template directories not matching any controller path" do
        FileUtils.mkdir_p("#{dummy_root}/app/views/components")
        FileUtils.touch("#{dummy_root}/app/views/components/_foo.html.erb")

        uri = Kernel.URI("file://#{dummy_root}/app/views/components/_bar.html.erb")
        source = <<~ERB
          <%= render "components/foo" %>
        ERB

        response = generate_definitions_for_source(source, { line: 0, character: 12 }, uri)
        assert_equal("file://#{dummy_root}/app/views/components/_foo.html.erb", response.first.uri)
      ensure
        FileUtils.rm_r("#{dummy_root}/app/views/components")
      end

      test "handles template formats, variants and handlers" do
        FileUtils.touch("#{dummy_root}/app/views/users/_partial.html.erb")
        FileUtils.touch("#{dummy_root}/app/views/users/_partial.text.erb")
        FileUtils.touch("#{dummy_root}/app/views/users/_partial.html.ruby")
        FileUtils.touch("#{dummy_root}/app/views/users/_partial.html+tablet.erb")
        FileUtils.touch("#{dummy_root}/app/views/users/_partial.html+mobile.erb")

        uri = Kernel.URI("file://#{dummy_root}/app/views/users/render.html.erb")
        source = <<~ERB
          <%= render "partial" %>
          <%= render "partial", formats: :html %>
          <%= render "partial", formats: [:text] %>
          <%= render "partial", handlers: :ruby %>
          <%= render "partial", handlers: [:erb] %>
          <%= render "partial", variants: :mobile %>
          <%= render "partial", variants: [:tablet, :mobile] %>
        ERB

        with_ready_server(source, uri) do |server|
          response = text_document_definition(server, { line: 0, character: 12 }, uri)
          assert_equal("file://#{dummy_root}/app/views/users/_partial.html.erb", response.first.uri)

          response = text_document_definition(server, { line: 1, character: 12 }, uri)
          assert_equal("file://#{dummy_root}/app/views/users/_partial.html.erb", response.first.uri)

          response = text_document_definition(server, { line: 2, character: 12 }, uri)
          assert_equal("file://#{dummy_root}/app/views/users/_partial.text.erb", response.first.uri)

          response = text_document_definition(server, { line: 3, character: 12 }, uri)
          assert_equal("file://#{dummy_root}/app/views/users/_partial.html.ruby", response.first.uri)

          response = text_document_definition(server, { line: 4, character: 12 }, uri)
          assert_equal("file://#{dummy_root}/app/views/users/_partial.html.erb", response.first.uri)

          response = text_document_definition(server, { line: 5, character: 12 }, uri)
          assert_equal("file://#{dummy_root}/app/views/users/_partial.html+mobile.erb", response.first.uri)

          response = text_document_definition(server, { line: 6, character: 12 }, uri)
          assert_equal("file://#{dummy_root}/app/views/users/_partial.html+tablet.erb", response.first.uri)
        end
      ensure
        FileUtils.rm(Dir["#{dummy_root}/app/views/users/_partial.*"])
      end

      private

      def generate_definitions_for_source(source, position, uri = Kernel.URI("file:///fake.rb"))
        with_ready_server(source, uri) do |server|
          text_document_definition(server, position, uri)
        end
      end

      def text_document_definition(server, position, uri)
        server.process_message(
          id: 1,
          method: "textDocument/definition",
          params: { textDocument: { uri: uri }, position: position },
        )

        result = pop_result(server)
        result.response
      end

      def with_ready_server(source, uri)
        with_server(source, uri) do |server|
          sleep(0.1) while RubyLsp::Addon.addons.first.instance_variable_get(:@rails_runner_client).is_a?(NullClient)

          yield server
        end
      end
    end
  end
end
