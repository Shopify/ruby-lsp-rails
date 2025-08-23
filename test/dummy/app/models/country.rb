# frozen_string_literal: true

class Country < ApplicationRecord
  has_one :flag, dependent: :destroy
end
