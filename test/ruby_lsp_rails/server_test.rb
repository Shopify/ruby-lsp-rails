# typed: true
# frozen_string_literal: true

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"
require_relative "../dummy/config/environment"

require "minitest/autorun"
require "mocha/minitest"
require "ruby_lsp/ruby_lsp_rails/server"

class ServerTest < ActiveSupport::TestCase
  setup do
    @stdout = StringIO.new
    @stderr = StringIO.new
    @server = RubyLsp::Rails::Server.new(stdout: @stdout, stderr: @stderr, override_default_output_device: false)
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
    assert_match %r{test/dummy/config/routes.rb:5$}, location
  end

  test "route location returns nil for invalid routes" do
    @server.execute("route_location", { name: "invalid_path" })
    assert_nil response[:result]
  end

  test "route info" do
    @server.execute("route_info", { controller: "UsersController", action: "index" })

    result = response[:result]

    source_location_path, source_location_line = result[:source_location]
    assert_equal "5", source_location_line
    assert source_location_path.end_with?("config/routes.rb")
    assert_equal "GET", result[:verb]
    assert_equal "/users(.:format)", result[:path]
  end

  test "server add-ons" do
    File.write("server_addon.rb", <<~RUBY)
      class TapiocaServerAddon < RubyLsp::Rails::ServerAddon
        def name
          "Tapioca"
        end

        def execute(request, params)
          send_message({ request:, params: })
        end
      end
    RUBY

    @server.execute("server_addon/register", server_addon_path: File.expand_path("server_addon.rb"))

    @server.execute("server_addon/delegate", server_addon_name: "Tapioca", request_name: "dsl")
    assert_equal(response, { params: {}, request: "dsl" })
  ensure
    FileUtils.rm("server_addon.rb")
  end

  test "checking for pending migrations" do
    capture_subprocess_io do
      system("bundle exec rails g migration CreateStudents name:string")
    end

    @server.execute("pending_migrations_message", {})
    message = response.dig(:result, :pending_migrations_message)
    assert_match("You have 1 pending migration", message)
    assert_match(%r{db/migrate/[\d]+_create_students\.rb}, message)
  ensure
    FileUtils.rm_rf("db") if File.directory?("db")
  end

  test "running migrations happens in a child process" do
    Open3.expects(:capture2)
      .with({ "VERBOSE" => "true" }, "bundle exec rails db:migrate")
      .returns(["Running migrations...", mock(exitstatus: 0)])

    @server.execute("run_migrations", {})
    assert_equal({ message: "Running migrations...", status: 0 }, response[:result])
  end

  test "shows error if there is a database connection error" do
    @server.expects(:pending_migrations_message).raises(ActiveRecord::ConnectionNotEstablished)
    @server.execute("pending_migrations_message", {})

    assert_equal(
      { error: "Request pending_migrations_message failed because database connection was not established." }, response
    )
  end

  test "shows error if database does not exist" do
    @server.expects(:pending_migrations_message).raises(ActiveRecord::NoDatabaseError)
    @server.execute("pending_migrations_message", {})

    assert_equal(
      { error: "Request pending_migrations_message failed because the database does not exist." },
      response,
    )
  end

  test "send_message uses bytesize for content length with ASCII characters" do
    @server.send(:send_message, { test: "hello" })
    assert_equal "Content-Length: 16\r\n\r\n{\"test\":\"hello\"}", @stdout.string
  end

  test "send_message uses bytesize for content length with multibyte characters" do
    @server.send(:send_message, { test: "こんにちは" }) # Japanese "hello"
    expected = "Content-Length: 26\r\n\r\n"
    expected += { test: "こんにちは" }.to_json.force_encoding(Encoding::ASCII_8BIT)
    assert_equal expected, @stdout.string
  end

  test "log_message sends notification to client" do
    @server.log_message("Hello")

    expected_notification = {
      method: "window/logMessage",
      params: { type: 4, message: "Hello" },
    }.to_json

    assert_equal "Content-Length: #{expected_notification.bytesize}\r\n\r\n#{expected_notification}", @stderr.string
  end

  test "log_message allows server to define message type" do
    @server.log_message("Hello", type: 1)

    expected_notification = {
      method: "window/logMessage",
      params: { type: 1, message: "Hello" },
    }.to_json

    assert_equal "Content-Length: #{expected_notification.bytesize}\r\n\r\n#{expected_notification}", @stderr.string
  end

  test "regular prints become structured log messages" do
    original_stdout = $stdout

    stdout = StringIO.new
    stderr = StringIO.new
    server = RubyLsp::Rails::Server.new(stdout: stdout, stderr: stderr, override_default_output_device: true)

    server.instance_eval do
      def print_it!
        puts "hello"
      end
    end

    server.print_it!

    assert_match("Content-Length: 70\r\n\r\n", stderr.string)
    assert_match(
      "{\"method\":\"window/logMessage\",\"params\":{\"type\":4,\"message\":\"hello\\n\"}}",
      stderr.string,
    )
  ensure
    $> = original_stdout
  end

  private

  def response
    _headers, content = @stdout.string.split("\r\n\r\n")
    JSON.parse(content, symbolize_names: true)
  end
end
