# typed: true
# frozen_string_literal: true

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"
require "mocha/minitest"
require "syntax_tree/dsl"
require "ruby_lsp/internal"
require "ruby_lsp/ruby_lsp_rails/extension"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("fixtures", __dir__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
  ActiveSupport::TestCase.fixtures(:all)
end

$VERBOSE = nil unless ENV["VERBOSE"] || ENV["CI"]

module ActiveSupport
  class TestCase
    include SyntaxTree::DSL

    def stub_http_request(code, body)
      response = mock("response")
      response.expects(:is_a?).with(Net::HTTPResponse).returns(true)
      response.expects(:code).returns("200")
      response.expects(:body).returns(body)

      Net::HTTP.stubs(:get_response).returns(response)
    end

    def setup
      File.write("test/dummy/tmp/app_uri.txt", "http://localhost:3000")
    end

    def teardown
      FileUtils.rm("test/dummy/tmp/app_uri.txt")
    end
  end
end
