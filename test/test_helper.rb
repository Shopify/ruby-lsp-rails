# typed: true
# frozen_string_literal: true

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "fileutils"
require "rails/test_help"
require "mocha/minitest"
require "syntax_tree/dsl"
require "ruby_lsp/internal"
require "ruby_lsp/ruby_lsp_rails/addon"

module ActiveSupport
  class TestCase
    include SyntaxTree::DSL

    TEST_ROOT = T.let(Pathname(T.must(__dir__)), Pathname)
    ROOT = TEST_ROOT.join("..")

    def stub_http_request(code, body)
      response = mock("response")
      response.expects(:is_a?).with(Net::HTTPResponse).returns(true)
      response.expects(:code).returns("200")
      response.expects(:body).returns(body)

      Net::HTTP.any_instance.expects(:get).returns(response)
    end

    setup do
      File.write("test/dummy/tmp/app_uri.txt", "http://localhost:3000")

      @old_root = RubyLsp::Rails::RailsClient.root
      RubyLsp::Rails::RailsClient.root = TEST_ROOT.join("dummy")
    end

    teardown do
      FileUtils.rm("test/dummy/tmp/app_uri.txt")

      RubyLsp::Rails::RailsClient.root = @old_root
    end
  end
end
