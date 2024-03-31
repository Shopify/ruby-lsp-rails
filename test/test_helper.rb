# typed: true
# frozen_string_literal: true

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"
ENV["RUBY_LSP_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "sorbet-runtime"
require "rails/test_help"
require "mocha/minitest"
require "ruby_lsp/internal"
require "ruby_lsp/test_helper"
require "ruby_lsp/ruby_lsp_rails/addon"
require "spoom/backtrace_filter/minitest"

if defined?(DEBUGGER__)
  DEBUGGER__::CONFIG[:skip_path] =
    Array(DEBUGGER__::CONFIG[:skip_path]) + Gem.loaded_specs["sorbet-runtime"].full_require_paths
end

begin
  require "spoom/backtrace_filter/minitest"
  Minitest.backtrace_filter = Spoom::BacktraceFilter::Minitest.new
rescue LoadError
  # Tapioca (and thus Spoom) is not available on Windows
end

module ActiveSupport
  class TestCase
    include RubyLsp::TestHelper

    def dummy_root
      File.expand_path("#{__dir__}/dummy")
    end

    # TODO: share with ruby-lsp?
    sig do
      type_parameters(:T)
        .params(
          source: T.nilable(String),
          uri: URI::Generic,
          block: T.proc.params(server: RubyLsp::Server, uri: URI::Generic).returns(T.type_parameter(:T)),
        ).returns(T.type_parameter(:T))
    end
    def with_server(source = nil, uri = URI("file:///fake.rb"), &block)
      server = ::RubyLsp::Server.new(test_mode: true)
      server.process_message({ method: "initialized" })

      if source
        server.process_message({
          id: 1,
          method: "textDocument/didOpen",
          params: {
            textDocument: {
              uri: uri,
              text: source,
              version: 1,
            },
          },
        })
      end

      index = server.index
      index.index_single(RubyIndexer::IndexablePath.new(nil, T.must(uri.to_standardized_path)), source)
      block.call(server, uri)
    ensure
      T.must(server).run_shutdown
    end
  end
end
