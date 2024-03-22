# typed: true
# frozen_string_literal: true

class User < ApplicationRecord
  before_create :foo, -> () {}
  validates :name, presence: true
  has_one :profile

  private

  def foo
    puts "test"
  end
end
