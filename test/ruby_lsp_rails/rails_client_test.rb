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
        File.write("#{Dir.pwd}/test/dummy/tmp/app_uri.txt", "http://localhost:3000")
        Net::HTTP.any_instance.expects(:get).raises(Net::ReadTimeout)

        assert_nil(RailsClient.new.model("User"))
      end

      test "instantiation finds the right directory when bundle gemfile points to .ruby-lsp" do
        skip if ENV["BUNDLE_GEMFILE"]&.end_with?("gemfiles/Gemfile-rails-main")

        previous_bundle_gemfile = ENV["BUNDLE_GEMFILE"]
        project_root = Pathname.new(previous_bundle_gemfile).dirname

        ENV["BUNDLE_GEMFILE"] = "#{project_root}/.ruby-lsp/Gemfile"
        assert_equal("#{project_root}/test/dummy", RailsClient.new.root.to_s)
      ensure
        ENV["BUNDLE_GEMFILE"] = previous_bundle_gemfile
      end

      test "check_if_server_is_running! warns if no server is found" do
        File.write("#{Dir.pwd}/test/dummy/tmp/app_uri.txt", "http://localhost:3000")
        Net::HTTP.any_instance.expects(:get).raises(Errno::ECONNREFUSED)

        assert_output("", RailsClient::SERVER_NOT_RUNNING_MESSAGE + "\n") do
          RailsClient.new.check_if_server_is_running!
        end
      end

      test "check_if_server_is_running! warns if connection fails" do
        File.write("#{Dir.pwd}/test/dummy/tmp/app_uri.txt", "http://localhost:3000")
        Net::HTTP.any_instance.expects(:get).raises(Errno::EADDRNOTAVAIL)

        assert_output("", RailsClient::SERVER_NOT_RUNNING_MESSAGE + "\n") do
          RailsClient.new.check_if_server_is_running!
        end
      end

      test "defaults path to localhost" do
        File.write("#{Dir.pwd}/test/dummy/tmp/app_uri.txt", "http://localhost:3000")

        client = RailsClient.new
        assert_equal("localhost", client.instance_variable_get(:@address))
        assert_equal(3000, client.instance_variable_get(:@port))
        refute(client.instance_variable_get(:@ssl))
      end
    end
  end
end
