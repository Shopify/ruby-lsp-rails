# typed: true
# frozen_string_literal: true

require "test_helper"
require "ruby_lsp/ruby_lsp_rails/server"

class ServerTest < ActiveSupport::TestCase
  setup do
    @server = RubyLsp::Rails::Server.new
  end

  test "returns nil if model doesn't exist" do
    response = @server.execute("model", { name: "Foo" })
    assert_nil(response.fetch(:result))
  end

  test "returns nil if class is not a model" do
    response = @server.execute("model", { name: "Time" })
    assert_nil(response.fetch(:result))
  end

  test "returns nil if class is an abstract model" do
    response = @server.execute("model", { name: "ApplicationRecord" })
    assert_nil(response.fetch(:result))
  end

  test "returns nil if constant is not a class" do
    response = @server.execute("model", { name: "RUBY_VERSION" })
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

    response = @server.execute("model", { name: "TestClassWithOverwrittenLessThan" })
    assert_nil(response.fetch(:result))
  end

  test "handles older Rails version which don't have `schema_dump_path`" do
    ActiveRecord::Tasks::DatabaseTasks.send(:alias_method, :old_schema_dump_path, :schema_dump_path)
    ActiveRecord::Tasks::DatabaseTasks.undef_method(:schema_dump_path)
    response = @server.execute("model", { name: "User" })
    assert_nil(response.fetch(:result)[:schema_file])
  ensure
    ActiveRecord::Tasks::DatabaseTasks.send(:alias_method, :schema_dump_path, :old_schema_dump_path)
  end

  test "resolve association returns the location of the target class of a has_many association" do
    response = @server.execute(
      "association_target_location",
      { model_name: "Organization", association_name: :memberships },
    )
    location = response[:result][:location]
    assert_match %r{test/dummy/app/models/membership.rb:3$}, location
  end

  test "resolve association returns the location of the target class of a belongs_to association" do
    response = @server.execute(
      "association_target_location",
      { model_name: "Membership", association_name: :organization },
    )
    location = response[:result][:location]
    assert_match %r{test/dummy/app/models/organization.rb:3$}, location
  end

  test "resolve association returns the location of the target class of a has_one association" do
    response = @server.execute(
      "association_target_location",
      { model_name: "User", association_name: :profile },
    )
    location = response[:result][:location]
    assert_match %r{test/dummy/app/models/profile.rb:3$}, location
  end

  test "resolve association returns the location of the target class of a has_and_belongs_to_many association" do
    response = @server.execute(
      "association_target_location",
      { model_name: "Profile", association_name: :labels },
    )
    location = response[:result][:location]
    assert_match %r{test/dummy/app/models/label.rb:3$}, location
  end

  test "resolve association handles invalid model name" do
    response = @server.execute(
      "association_target_location",
      { model_name: "NotHere", association_name: :labels },
    )
    assert_nil(response.fetch(:result))
  end

  test "resolve association handles invalid association name" do
    response = @server.execute(
      "association_target_location",
      { model_name: "Membership", association_name: :labels },
    )
    assert_nil(response.fetch(:result))
  end

  test "resolve association handles class_name option" do
    response = @server.execute(
      "association_target_location",
      { model_name: "User", association_name: :location },
    )
    location = response[:result][:location]
    assert_match %r{test/dummy/app/models/country.rb:3$}, location
  end

  test "route location returns the location for a valid route" do
    response = @server.execute("route_location", { name: "user_path" })
    location = response[:result][:location]
    assert_match %r{test/dummy/config/routes.rb:4$}, location
  end

  test "route location returns nil for invalid routes" do
    response = @server.execute("route_location", { name: "invalid_path" })
    assert_nil response[:result]
  end

  test "route info" do
    response = @server.execute("route_info", { controller: "UsersController", action: "index" })

    result = response[:result]

    source_location_path, source_location_line = result[:source_location]
    assert_equal "4", source_location_line
    assert source_location_path.end_with?("config/routes.rb")
    assert_equal "GET", result[:verb]
    assert_equal "/users(.:format)", result[:path]
  end

  test "require_server_addon raises if addon does not exist" do
    error = assert_raises do
      RubyLsp::Rails::Server.require_server_addon("invalid")
    end
    assert_equal "Failed to load addon 'invalid'", error.message
  end

  test "reports and error if server addon request format is invalid" do
    response = @server.execute("foo.", {})
    assert_equal "Invalid request format: foo.", response.fetch(:error)

    response = @server.execute(".bar", {})
    assert_equal "Invalid request format: .bar", response.fetch(:error)
  end

  test "reports an error is server addon setup fails" do
    response = @server.execute("foo.bar", {})
    assert_equal "Addon 'foo' setup failed", response.fetch(:error)
  end
end
