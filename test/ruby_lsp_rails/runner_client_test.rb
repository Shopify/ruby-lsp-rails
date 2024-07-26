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

        # On Windows, the server process sometimes takes a lot longer to shutdown and may end up getting force killed,
        # which makes this assertion flaky
        assert_predicate(@client, :stopped?) unless Gem.win_platform?
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
          ["country_id", "integer"],
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
        FileUtils.mv("test/dummy/config/application.rb", "test/dummy/config/application.rb.bak")
        assert_output(
          "",
          /Ruby LSP Rails failed to initialize server/,
        ) do
          client = RunnerClient.create_client

          assert_instance_of(NullClient, client)
          assert_nil(client.model("User"))
          assert_predicate(client, :stopped?)
        end
      ensure
        FileUtils.mv("test/dummy/config/application.rb.bak", "test/dummy/config/application.rb")
      end

      test "is resilient to extra output being printed during boot" do
        content = File.read("test/dummy/config/application.rb")
        FileUtils.mv("test/dummy/config/application.rb", "test/dummy/config/application.rb.bak")
        junk = %{\nputs "1\r\n\r\nhello"}
        File.write("test/dummy/config/application.rb", content + junk)

        capture_subprocess_io do
          client = RunnerClient.create_client

          response = T.must(client.model("User"))
          assert(response.key?(:columns))
        end
      ensure
        FileUtils.mv("test/dummy/config/application.rb.bak", "test/dummy/config/application.rb")
      end
    end

    class NullClientTest < ActiveSupport::TestCase
      setup { @client = NullClient.new }

      test "#shutdown is a no-op" do
        assert_nothing_raised { @client.shutdown }
      end

      test "#stopped? is always true" do
        assert_predicate @client, :stopped?
      end

      test "#rails_root is just the current working directory" do
        assert_equal Dir.pwd, @client.rails_root
      end

      test "#send_message is a no-op" do
        assert_nothing_raised { @client.send(:send_message, "request", nil) }
      end

      test "#send_notification is a no-op" do
        assert_nothing_raised { @client.send(:send_notification, "request", nil) }
      end

      test "#read_response is a no-op" do
        assert_nothing_raised { @client.send(:read_response) }
      end
    end
  end
end
