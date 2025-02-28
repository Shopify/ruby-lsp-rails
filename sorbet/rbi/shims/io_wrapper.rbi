# typed: strict
# frozen_string_literal: true

class RubyLsp::Rails::IOWrapper
  sig { params(message: String).void }
  def write(message)
  end
end
