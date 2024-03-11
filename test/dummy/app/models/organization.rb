# typed: true
# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :users
end
