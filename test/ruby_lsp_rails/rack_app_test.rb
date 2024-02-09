# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class RackAppTest < ActionDispatch::IntegrationTest
      test "GET model route returns column information for existing models" do
        get "/ruby_lsp_rails/models/User"
        assert_response(:success)
        assert_equal(
          {
            "schema_file" => "#{RailsClient.root}/db/schema.rb",
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

      test "GET model route returns not_found if model doesn't exist" do
        get "/ruby_lsp_rails/models/Foo"
        assert_response(:not_found)
      end

      test "GET model route returns not_found if class is not a model" do
        get "/ruby_lsp_rails/models/Time"
        assert_response(:not_found)
      end

      test "GET show returns not_found if class is an abstract model" do
        get "/ruby_lsp_rails/models/ApplicationRecord"
        assert_response(:not_found)
      end

      test "GET route route returns info on a given route" do
        get "/ruby_lsp_rails/route?controller=UsersController&action=index"
        assert_response(:success)

        assert_equal(
          {
            "source_location" => ["#{ROOT}/config/routes.rb", "8"],
            "verb" => "GET",
            "path" => "/users(.:format)",
          },
          JSON.parse(response.body),
        )
      end

      test "GET route route returns not found when route cannot be found" do
        get "/ruby_lsp_rails/route?controller=UsersController&action=show"
        assert_response(:not_found)
      end

      test "GET activate returns success to display that server is running" do
        get "/ruby_lsp_rails/activate"
        assert_response(:success)
      end
    end
  end
end
