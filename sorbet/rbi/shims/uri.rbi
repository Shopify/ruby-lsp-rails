# typed: strict
# frozen_string_literal: true

module URI
  class Generic
    class << self
      sig do
        params(
          path: String,
          fragment: T.nilable(String),
          scheme: String,
          load_path_entry: T.nilable(String),
        ).returns(URI::Generic)
      end
      def from_path(path:, fragment: nil, scheme: "file", load_path_entry: nil); end
    end

    sig { returns(T.nilable(String)) }
    def to_standardized_path; end
  end
end
