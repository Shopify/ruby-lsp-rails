# typed: strict
# frozen_string_literal: true

require "json"
require "open3"

# NOTE: We should avoid printing to stderr since it causes problems. We never read the standard error pipe
# from the client, so it will become full and eventually hang or crash.
# Instead, return a response with an `error` key.

module RubyLsp
  module Rails
    class RunnerClient
      extend T::Sig

      sig { void }
      def initialize
        stdin, stdout, stderr, wait_thread = Open3.popen3(
          "bin/rails",
          "runner",
          "#{__dir__}/server.rb",
          "start",
        )
        @stdin = T.let(stdin, IO)
        @stdout = T.let(stdout, IO)
        @stderr = T.let(stderr, IO)
        @wait_thread = T.let(wait_thread, Process::Waiter)
        @stdin.binmode # for Windows compatibility
        @stdout.binmode # for Windows compatibility
      end

      sig { params(name: String).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def model(name)
        make_request("model", name: name)
      end

      sig { void }
      def shutdown
        send_notification("shutdown")
        Thread.pass while @wait_thread.alive?
        [@stdin, @stdout, @stderr].each(&:close)
      end

      sig { returns(T::Boolean) }
      def stopped?
        [@stdin, @stdout, @stderr].all?(&:closed?) && !@wait_thread.alive?
      end

      private

      sig { params(request: T.untyped, params: T.untyped).returns(T.untyped) }
      def make_request(request, params = nil)
        send_message(request, params)
        read_response
      end

      sig { params(request: T.untyped, params: T.untyped).void }
      def send_message(request, params = nil)
        message = { method: request }
        message[:params] = params if params
        json = message.to_json

        @stdin.write("Content-Length: #{json.length}\r\n\r\n", json)
      end

      alias_method :send_notification, :send_message

      sig { returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def read_response
        headers = @stdout.gets("\r\n\r\n")
        raw_response = @stdout.read(T.must(headers)[/Content-Length: (\d+)/i, 1].to_i)

        response = JSON.parse(T.must(raw_response), symbolize_names: true)

        if response[:error]
          warn("Ruby LSP Rails error: " + response[:error])
          return
        end

        response.fetch(:result)
      end
    end
  end
end
