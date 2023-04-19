# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
