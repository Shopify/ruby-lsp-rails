# typed: true
# frozen_string_literal: true

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"
require "mocha/minitest"
require "ruby_lsp/internal"
require "ruby_lsp/test_helper"
require "ruby_lsp/ruby_lsp_rails/addon"

ActiveRecord::Tasks::DatabaseTasks.fixtures_path = File.expand_path("fixtures", __dir__)

module ActiveSupport
  class TestCase
    include RubyLsp::TestHelper

    fixtures :all

    def dummy_root
      File.expand_path("#{__dir__}/dummy")
    end
  end
end
