# typed: true
# frozen_string_literal: true

require "test_helper"
require "ruby_lsp/ruby_lsp_rails/runner_client"

module RubyLsp
  module Rails
    class RunnerClientTest < ActiveSupport::TestCase
      setup do
        capture_io do
          @client = T.let(RunnerClient.new, RunnerClient)
        end
      end

      teardown do
        @client.shutdown
        assert_predicate @client, :stopped?
      end

      # These are integration tests which start the server. For the more fine-grained tests, see `server_test.rb`.

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

      test "returns nil if the request returns a nil response" do
        assert_nil @client.model("ApplicationRecord") # ApplicationRecord is abstract
      end

      test "failing to spawn server creates a null client" do
        FileUtils.mv("bin/rails", "bin/rails_backup")

        assert_output("", %r{No such file or directory - bin/rails}) do
          client = RunnerClient.create_client

          assert_instance_of(NullClient, client)
          assert_nil(client.model("User"))
          assert_predicate(client, :stopped?)
        end
      ensure
        FileUtils.mv("bin/rails_backup", "bin/rails")
      end
    end
  end
end
