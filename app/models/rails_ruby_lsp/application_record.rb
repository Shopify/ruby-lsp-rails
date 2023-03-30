# typed: strict
# frozen_string_literal: true

module RailsRubyLsp
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
