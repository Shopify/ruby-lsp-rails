# frozen_string_literal: true

class User < ApplicationRecord
  before_create :foo, -> () {}
  validates :name, presence: true
  has_one :profile
  scope :adult, -> { where(age: 18..) }

  attr_readonly :last_name

  private

  def foo
    puts "test"
  end
end
