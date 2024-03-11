# typed: true
# frozen_string_literal: true

class User < ApplicationRecord
  before_create :foo_arg, -> () {}

  has_many :widgets
  has_one :address
  belongs_to :organization
end
