# typed: true
# frozen_string_literal: true

class User < ApplicationRecord
  has_one :address
end
