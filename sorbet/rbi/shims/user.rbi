# typed: strict
# frozen_string_literal: true

class User
  class << self
    sig { params(association_name: Symbol).void }
    def has_many(association_name)
    end

    sig { returns(T::Hash[String, T.untyped]) }
    def reflections
    end
  end
end
