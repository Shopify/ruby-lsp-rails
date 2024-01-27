# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class RackAppTest < ActionDispatch::IntegrationTest
      test "GET show returns schema information" do
        get "/ruby_lsp_rails/models/User"
        assert_response(:success)
        body = JSON.parse(response.body)
        assert_equal(body["schema_file"], "#{RailsClient.new.root}/db/schema.rb")
      end

      test "GET show returns column information for existing models" do
        get "/ruby_lsp_rails/models/User"
        assert_response(:success)
        body = JSON.parse(response.body)
        [
          { name: "id", type: "integer", comment: nil },
          { name: "first_name", type: "string", comment: nil },
          { name: "last_name", type: "string", comment: nil },
          { name: "age", type: "integer", comment: nil },
          { name: "created_at", type: "datetime", comment: nil },
          { name: "updated_at", type: "datetime", comment: nil },
        ].each do |column|
          assert_equal(body["columns"].any? { |h| h["name"] == column[:name] }, true)
          model = body["columns"].select { |c| c["name"] == column[:name] }.first
          assert_equal(model["name"], column[:name])
          assert_equal(model["type"], column[:type])

          if column[:comment].nil?
            assert_nil(model["comment"], column[:comment])
          else
            assert_equal(model["comment"], column[:comment])
          end
        end
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
