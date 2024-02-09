# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class SchemaCollectorTest < ActiveSupport::TestCase
      SCHEMA_FILE = <<~RUBY
        ActiveRecord::Schema[7.1].define(version: 2023_12_09_114241) do
          create_table "cats", force: :cascade do |t|
          end

          create_table "dogs", force: :cascade do |t|
          end
        end
      RUBY

      test "store locations of models by parsing create_table calls" do
        collector = RubyLsp::Rails::SchemaCollector.new(Pathname.new("example_app"))
        Prism.parse(SCHEMA_FILE).value.accept(collector)

        assert_equal(["cats", "dogs"], collector.tables.keys)
      end
    end
  end
end
