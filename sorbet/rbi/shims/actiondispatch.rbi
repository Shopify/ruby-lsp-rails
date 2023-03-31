# typed: strict
# frozen_string_literal: true

module ActionDispatch
  class IntegrationTest
    sig { params(id: String).returns(String) }
    def model_url(id:); end
  end
end
