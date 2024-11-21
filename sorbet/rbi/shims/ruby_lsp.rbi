# typed: strict
# frozen_string_literal: true

module RubyIndexer
  class Enhancement
    def initialize(listener)
      @listener = T.let(listener, RubyIndexer::DeclarationListener)
    end
  end
end
