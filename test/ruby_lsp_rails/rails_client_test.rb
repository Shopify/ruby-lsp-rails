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
        assert_equal(expected_response, RailsClient.instance.model("User"))
      end

      test "model returns nil when failing to open TCP connections" do
        Net::HTTP.any_instance.expects(:get).raises(Errno::EADDRNOTAVAIL)

        assert_nil(RailsClient.instance.model("User"))
      end

      test "model returns nil when requests timeout" do
        Net::HTTP.any_instance.expects(:get).raises(Net::ReadTimeout)

        assert_nil(RailsClient.instance.model("User"))
      end

      test "instantiation finds the right directory when bundle gemfile points to .ruby-lsp" do
        previous_bundle_gemfile = ENV["BUNDLE_GEMFILE"]
        project_root = Pathname.new(previous_bundle_gemfile).dirname

        # If the RailsClient singleton was initialized in a different test successfully, then there would be no chance
        # for this assertion to pass. We need to reset the singleton instance in order to force `initialize` to be
        # executed again
        Singleton.send(:__init__, RailsClient)

        ENV["BUNDLE_GEMFILE"] = "#{project_root}/.ruby-lsp/Gemfile"
        assert_equal("#{project_root}/test/dummy", RailsClient.instance.root)
      ensure
        ENV["BUNDLE_GEMFILE"] = previous_bundle_gemfile
      end

      test "check_if_server_is_running! warns if no server is found" do
        Net::HTTP.any_instance.expects(:get).raises(Errno::ECONNREFUSED)

        assert_output("", RailsClient::SERVER_NOT_RUNNING_MESSAGE + "\n") do
          RailsClient.instance.check_if_server_is_running!
        end
      end

      test "check_if_server_is_running! warns if connection fails" do
        Net::HTTP.any_instance.expects(:get).raises(Errno::EADDRNOTAVAIL)

        assert_output("", RailsClient::SERVER_NOT_RUNNING_MESSAGE + "\n") do
          RailsClient.instance.check_if_server_is_running!
        end
      end
    end
  end
end
