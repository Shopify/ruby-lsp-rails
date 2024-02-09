# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class RailsClientTest < ActiveSupport::TestCase
      test "model returns information for the requested model" do
        expected_response = {
          columns: [
            ["id", "integer"],
            ["first_name", "string"],
            ["last_name", "string"],
            ["age", "integer"],
            ["created_at", "datetime"],
            ["updated_at", "datetime"],
          ],
        }

        stub_http_request("200", expected_response.to_json)
        assert_equal(expected_response, RailsClient.new.model("User"))
      end

      test "model returns nil when failing to open TCP connections" do
        Net::HTTP.any_instance.expects(:get).raises(Errno::EADDRNOTAVAIL)

        assert_nil(RailsClient.new.model("User"))
      end

      test "model returns nil when requests timeout" do
        Net::HTTP.any_instance.expects(:get).raises(Net::ReadTimeout)

        assert_nil(RailsClient.new.model("User"))
      end

      test "instantiation finds the right directory when bundle gemfile points to .ruby-lsp" do
        previous_bundle_gemfile = ENV["BUNDLE_GEMFILE"]
        project_root = File.expand_path("../..", __dir__)

        ENV["BUNDLE_GEMFILE"] = "#{project_root}/.ruby-lsp/Gemfile"
        assert_equal("#{project_root}/test/dummy", RailsClient.new.root.to_s)
      ensure
        ENV["BUNDLE_GEMFILE"] = previous_bundle_gemfile
      end

      test "check_if_server_is_running! warns if no server is found" do
        Net::HTTP.any_instance.expects(:get).raises(Errno::ECONNREFUSED)

        assert_output("", RailsClient::SERVER_NOT_RUNNING_MESSAGE + "\n") do
          RailsClient.new.check_if_server_is_running!
        end
      end

      test "check_if_server_is_running! warns if connection fails" do
        Net::HTTP.any_instance.expects(:get).raises(Errno::EADDRNOTAVAIL)

        assert_output("", RailsClient::SERVER_NOT_RUNNING_MESSAGE + "\n") do
          RailsClient.new.check_if_server_is_running!
        end
      end

      test "route returns information for the requested route" do
        expected_response = {
          source_location: ["/app/config/routes.rb", 3],
          verb: "GET",
          path: "/users(.:format)",
        }

        stub_http_request("200", expected_response.to_json)
        assert_equal(expected_response, RailsClient.new.route(controller: "UsersController", action: "index"))
      end

      test "route returns nil when failing to open TCP connections" do
        Net::HTTP.any_instance.expects(:get).raises(Errno::EADDRNOTAVAIL)

        assert_nil(RailsClient.new.route(controller: "UsersController", action: "index"))
      end

      test "route returns nil when requests timeout" do
        Net::HTTP.any_instance.expects(:get).raises(Net::ReadTimeout)

        assert_nil(RailsClient.new.route(controller: "UsersController", action: "index"))
      end

      test "defaults path to localhost" do
        client = RailsClient.new
        assert_equal("localhost", client.instance_variable_get(:@address))
        assert_equal(3000, client.instance_variable_get(:@port))
        refute(client.instance_variable_get(:@ssl))
      end
    end
  end
end
