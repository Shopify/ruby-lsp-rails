# typed: strict
# frozen_string_literal: true

module URI
  class Generic
    # class << self
    #   sig { params(path: String, fragment: T.nilable(String), scheme: String).returns(URI::Generic) }
    #   def from_path(path:, fragment: nil, scheme: "file"); end
    # end

    sig { returns(T.nilable(String)) }
    def to_standardized_path; end
  end
end
