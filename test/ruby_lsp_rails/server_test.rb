# typed: true
# frozen_string_literal: true

require "test_helper"
require "ruby_lsp/ruby_lsp_rails/server"

class ServerTest < ActiveSupport::TestCase
  test "returns nil if model doesn't exist" do
    response = RubyLsp::Rails::Server.new.resolve_database_info_from_model("Foo")
    assert_nil(response.fetch(:result))
  end

  test "returns nil if class is not a model" do
    response = RubyLsp::Rails::Server.new.resolve_database_info_from_model("Time")
    assert_nil(response.fetch(:result))
  end

  test "returns nil if class is an abstract model" do
    response = RubyLsp::Rails::Server.new.resolve_database_info_from_model("ApplicationRecord")
    assert_nil(response.fetch(:result))
  end

  test "handles older Rails version which don't have `schema_dump_path`" do
    ActiveRecord::Tasks::DatabaseTasks.send(:alias_method, :old_schema_dump_path, :schema_dump_path)
    ActiveRecord::Tasks::DatabaseTasks.undef_method(:schema_dump_path)
    response = RubyLsp::Rails::Server.new.resolve_database_info_from_model("User")
    assert_nil(response.fetch(:result)[:schema_file])
  ensure
    ActiveRecord::Tasks::DatabaseTasks.send(:alias_method, :schema_dump_path, :old_schema_dump_path)
  end
end
