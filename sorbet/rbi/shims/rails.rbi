# typed: strict
# frozen_string_literal: true

module Rails
  class << self
    sig { returns(Application) }
    def application; end
  end

  class Server
    class Options
      def parse!(args); end
    end
  end

  class Application
    sig { params(block: T.proc.bind(Rails::Application).void).void }
    def configure(&block); end
  end
end
