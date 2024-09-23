# typed: true
# frozen_string_literal: true

require "test_helper"
require "ruby_lsp/ruby_lsp_rails/server"

class ServerTest < ActiveSupport::TestCase
  setup do
    @stdout = StringIO.new
    @server = RubyLsp::Rails::Server.new(stdout: @stdout, override_default_output_device: false)
  end

  test "returns nil if model doesn't exist" do
    @server.execute("model", { name: "Foo" })
    assert_nil(response.fetch(:result))
  end

  test "returns nil if class is not a model" do
    @server.execute("model", { name: "Time" })
    assert_nil(response.fetch(:result))
  end

  test "returns nil if class is an abstract model" do
    @server.execute("model", { name: "ApplicationRecord" })
    assert_nil(response.fetch(:result))
  end

  test "returns nil if constant is not a class" do
    @server.execute("model", { name: "RUBY_VERSION" })
    assert_nil(response.fetch(:result))
  end

  test "doesn't fail if the class overrides `<`" do
    class TestClassWithOverwrittenLessThan
      class << self
        def <(other)
          raise
        end
      end
    end

    @server.execute("model", { name: "TestClassWithOverwrittenLessThan" })
    assert_nil(response.fetch(:result))
  end

  test "handles older Rails version which don't have `schema_dump_path`" do
    ActiveRecord::Tasks::DatabaseTasks.send(:alias_method, :old_schema_dump_path, :schema_dump_path)
    ActiveRecord::Tasks::DatabaseTasks.undef_method(:schema_dump_path)
    @server.execute("model", { name: "User" })
    assert_nil(response.fetch(:result)[:schema_file])
  ensure
    ActiveRecord::Tasks::DatabaseTasks.send(:alias_method, :schema_dump_path, :old_schema_dump_path)
  end

  test "resolve association returns the location of the target class of a has_many association" do
    @server.execute(
      "association_target_location",
      { model_name: "Organization", association_name: :memberships },
    )
    location = response[:result][:location]
    assert_match %r{test/dummy/app/models/membership.rb:3$}, location
  end

  test "resolve association returns the location of the target class of a belongs_to association" do
    @server.execute(
      "association_target_location",
      { model_name: "Membership", association_name: :organization },
    )
    location = response[:result][:location]
    assert_match %r{test/dummy/app/models/organization.rb:3$}, location
  end

  test "resolve association returns the location of the target class of a has_one association" do
    @server.execute(
      "association_target_location",
      { model_name: "User", association_name: :profile },
    )
    location = response[:result][:location]
    assert_match %r{test/dummy/app/models/profile.rb:3$}, location
  end

  test "resolve association returns the location of the target class of a has_and_belongs_to_many association" do
    @server.execute(
      "association_target_location",
      { model_name: "Profile", association_name: :labels },
    )
    location = response[:result][:location]
    assert_match %r{test/dummy/app/models/label.rb:3$}, location
  end

  test "resolve association handles invalid model name" do
    @server.execute(
      "association_target_location",
      { model_name: "NotHere", association_name: :labels },
    )
    assert_nil(response.fetch(:result))
  end

  test "resolve association handles invalid association name" do
    @server.execute(
      "association_target_location",
      { model_name: "Membership", association_name: :labels },
    )
    assert_nil(response.fetch(:result))
  end

  test "resolve association handles class_name option" do
    @server.execute(
      "association_target_location",
      { model_name: "User", association_name: :location },
    )
    location = response[:result][:location]
    assert_match %r{test/dummy/app/models/country.rb:3$}, location
  end

  test "route location returns the location for a valid route" do
    @server.execute("route_location", { name: "user_path" })
    location = response[:result][:location]
    assert_match %r{test/dummy/config/routes.rb:4$}, location
  end

  test "route location returns nil for invalid routes" do
    @server.execute("route_location", { name: "invalid_path" })
    assert_nil response[:result]
  end

  test "route info" do
    @server.execute("route_info", { controller: "UsersController", action: "index" })

    result = response[:result]

    source_location_path, source_location_line = result[:source_location]
    assert_equal "4", source_location_line
    assert source_location_path.end_with?("config/routes.rb")
    assert_equal "GET", result[:verb]
    assert_equal "/users(.:format)", result[:path]
  end

  test "server addons" do
    File.write("server_addon.rb", <<~RUBY)
      class TapiocaServerAddon < RubyLsp::Rails::ServerAddon
        def name
          "Tapioca"
        end

        def execute(request, params)
          write_response({ request:, params: })
        end
      end
    RUBY

    @server.execute("server_addon/register", server_addon_path: File.expand_path("server_addon.rb"))

    @server.execute("server_addon/delegate", server_addon_name: "Tapioca", request_name: "dsl")
    assert_equal(response, { params: {}, request: "dsl" })
  ensure
    FileUtils.rm("server_addon.rb")
  end

  test "prints in the Rails application or server are automatically redirected to stderr" do
    stdout = StringIO.new
    server = RubyLsp::Rails::Server.new(stdout: stdout)

    server.instance_eval do
      def resolve_route_info(requirements)
        puts "Hello"
        super
      end
    end

    _, stderr = capture_subprocess_io do
      server.execute("route_info", { controller: "UsersController", action: "index" })
    end

    refute_match("Hello", stdout.string)
    assert_equal("Hello\n", stderr)
  end

  private

  def response
    _headers, content = @stdout.string.split("\r\n\r\n")
    JSON.parse(content, symbolize_names: true)
  end
end
