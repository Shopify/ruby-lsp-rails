# typed: true
# frozen_string_literal: true

class Part < ApplicationRecord
  has_and_belongs_to_many :assemblies
end
