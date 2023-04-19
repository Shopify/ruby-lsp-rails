# typed: strict
# frozen_string_literal: true

module ActionDispatch
  class IntegrationTest
    sig { params(model: String).returns(String) }
    def model_url(model:); end
  end
end
