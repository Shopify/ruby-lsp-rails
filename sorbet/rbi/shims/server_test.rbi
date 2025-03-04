# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    class Server
      # We need this since RBS doesn't yet have a replacement for T.unsafe()
      def print_it!; end
    end
  end
end
