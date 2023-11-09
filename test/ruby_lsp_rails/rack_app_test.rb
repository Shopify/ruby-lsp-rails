# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class RackAppTest < ActionDispatch::IntegrationTest
      test "GET show returns column information for existing models" do
        get "/ruby_lsp_rails/models/User"
        assert_response(:success)
        assert_equal(
          {
            "schema_file" => "#{RailsClient.new.root}/db/schema.rb",
            "columns" => [
              ["id", "integer"],
              ["first_name", "string"],
              ["last_name", "string"],
              ["age", "integer"],
              ["created_at", "datetime"],
              ["updated_at", "datetime"],
            ],
          },
          JSON.parse(response.body),
        )
      end

      test "GET show returns not_found if model doesn't exist" do
        get "/ruby_lsp_rails/models/Foo"
        assert_response(:not_found)
      end

      test "GET show returns not_found if class is not a model" do
        get "/ruby_lsp_rails/models/Time"
        assert_response(:not_found)
      end

      test "GET activate returns success to display that server is running" do
        get "/ruby_lsp_rails/activate"
        assert_response(:success)
      end
    end
  end
end
