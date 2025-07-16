# frozen_string_literal: true

class User < ApplicationRecord
  before_create :foo, -> () {}
  validates :first_name, presence: true
  has_one :profile
  scope :adult, -> { where(age: 18..) }
  belongs_to :location, class_name: "Country"
  has_one :country_flag, through: :location, source: :flag

  attr_readonly :last_name

  include Verifiable # an ActiveSupport::Concern

  private

  def foo
    puts "test"
  end
end
