# typed: true
# frozen_string_literal: true

class Address < ApplicationRecord
  belongs_to :user
end
