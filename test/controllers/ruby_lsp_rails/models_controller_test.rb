# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class ModelsControllerTest < ActionDispatch::IntegrationTest
      T.unsafe(self).include(Engine.routes.url_helpers)

      test "GET show returns column information for existing models" do
        get model_url(id: "User")
        assert_response(:success)
        assert_equal(
          {
            "schema_file" => "#{RailsClient.instance.root}/db/schema.rb",
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
        get model_url(id: "NonExistentModel")
        assert_response(:not_found)
      end

      test "GET show returns not_found if class is not a model" do
        get model_url(id: "ApplicationJob")
        assert_response(:not_found)
      end
    end
  end
end
