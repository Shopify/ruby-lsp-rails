# typed: true
# frozen_string_literal: true

require "test_helper"
require "ruby_lsp/ruby_lsp_rails/runner_client"

module RubyLsp
  module Rails
    class RunnerClientTest < ActiveSupport::TestCase
      setup do
        capture_subprocess_io do
          @client = T.let(RunnerClient.new, RunnerClient)
        end
      end

      teardown do
        capture_subprocess_io { @client.shutdown }
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

      test "falls back to null client when bin/rails is not found" do
        FileUtils.mv("bin/rails", "bin/rails_backup")

        assert_output("", %r{Ruby LSP Rails failed to locate bin/rails in the current directory}) do
          client = RunnerClient.create_client

          assert_instance_of(NullClient, client)
          assert_nil(client.model("User"))
          assert_predicate(client, :stopped?)
        end
      ensure
        FileUtils.mv("bin/rails_backup", "bin/rails")
      end

      test "failing to spawn server creates a null client" do
        FileUtils.mv("bin/rails", "bin/rails_backup")
        File.open("bin/rails", "w") do |f|
          f.write("foo")
        end
        File.chmod(0o755, "bin/rails")

        # The error message is slightly different on Ubuntu, so we need to allow for that
        assert_output(
          "",
          %r{Ruby LSP Rails failed to initialize server: bin/rails: (line )?1: foo:( command)? not found},
        ) do
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
