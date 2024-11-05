# typed: true
# frozen_string_literal: true

require "ruby_lsp/internal"
require "minitest/autorun"
require "test_declarative"
require "mocha/minitest"
require "ruby_lsp/test_helper"
require "ruby_lsp/ruby_lsp_rails/addon"

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

module Minitest
  class Test
    extend T::Sig
    include RubyLsp::TestHelper

    def dummy_root
      File.expand_path("#{__dir__}/dummy")
    end

    sig { params(server: RubyLsp::Server).returns(RubyLsp::Result) }
    def pop_result(server)
      result = server.pop_response
      result = server.pop_response until result.is_a?(RubyLsp::Result) || result.is_a?(RubyLsp::Error)

      refute_instance_of(
        RubyLsp::Error,
        result,
        -> { "Failed to execute request #{T.cast(result, RubyLsp::Error).message}" },
      )
      T.cast(result, RubyLsp::Result)
    end

    def pop_log_notification(message_queue, type)
      log = message_queue.pop
      return log if log.params.type == type

      log = message_queue.pop until log.params.type == type
      log
    end

    def pop_message(outgoing_queue, &block)
      message = outgoing_queue.pop
      return message if block.call(message)

      message = outgoing_queue.pop until block.call(message)
      message
    end

    # Copied from Rails
    def assert_nothing_raised(*args)
      msg = if Module === args.last
        nil
      else
        args.pop
      end
      begin
        line = __LINE__
        yield
      rescue MiniTest::Skip
        raise
      rescue Exception => e # rubocop:disable Lint/RescueException
        bt = e.backtrace
        as = e.instance_of?(MiniTest::Assertion)
        if as
          ans = /\A#{Regexp.quote(__FILE__)}:#{line}:in /
          bt.reject! { |ln| ans =~ ln }
        end
        if (args.empty? && !as) ||
            args.any? { |a| a.instance_of?(Module) ? e.is_a?(a) : e.class == a }
          msg = message(msg) { "Exception raised:\n<#{mu_pp(e)}>" }
          raise MiniTest::Assertion, msg.call, bt
        else
          raise
        end
      end
      nil
    end
  end
end
