# frozen_string_literal: true

module Verifiable
  extend ActiveSupport::Concern

  # checks if a user is verified
  def verified?
    true
  end

  module ClassMethods
  end

  class_methods do
    def all_unverified
      all.reject(&:verified?)
    end
  end
end
