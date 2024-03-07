# typed: true
# frozen_string_literal: true

class User < ApplicationRecord
  before_create :foo_arg, -> () {}
end
