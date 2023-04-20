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

      test "raises during instantiation if app_uri file doesn't exist" do
        project_root = Pathname.new(ENV["BUNDLE_GEMFILE"]).dirname
        app_uri_path = "#{project_root}/test/dummy/tmp/app_uri.txt"
        FileUtils.rm(app_uri_path)

        # If the RailsClient singleton was initialized in a different test successfully, then there would be no chance
        # for this assertion to pass. We need to reset the singleton instance in order to force `initialize` to be
        # executed again
        Singleton.send(:__init__, RailsClient)

        assert_raises(RailsClient::NeedsRestartError) do
          RailsClient.instance
        end
      ensure
        File.write(T.must(app_uri_path), "http://localhost:3000")
      end
    end
  end
end
