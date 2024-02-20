# typed: true
# frozen_string_literal: true

require "test_helper"
require "ruby_lsp/ruby_lsp_rails/runner_client"

module RubyLsp
  module Rails
    class RunnerClientTest < ActiveSupport::TestCase
      setup do
        @client = T.let(RunnerClient.new, RunnerClient)
      end

      teardown do
        @client.shutdown
        assert_predicate @client, :stopped?
      end

      # This is an integration test which starts the server. For the more fine-grained tests, see `server_test.rb`.
      test "#model returns information for the requested model" do
        # These columns are from the schema in the dummy app: test/dummy/db/schema.rb
        columns = [
          ["id", "integer"],
          ["first_name", "string"],
          ["last_name", "string"],
          ["age", "integer"],
          ["created_at", "datetime"],
          ["updated_at", "datetime"],
        ]
        response = T.must(@client.model("User"))
        assert_equal(columns, response.fetch(:columns))
        assert_match(%r{db/schema\.rb$}, response.fetch(:schema_file))
      end
    end
  end
end
