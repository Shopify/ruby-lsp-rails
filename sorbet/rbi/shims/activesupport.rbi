# typed: strict
# frozen_string_literal: true

module ActiveSupport
  class TestCase
    class << self
      sig { returns(String) }
      attr_accessor :fixture_path

      sig { params(key: Symbol).returns(T::Hash[Symbol, T.untyped]) }
      def fixtures(key); end
    end
  end
end
