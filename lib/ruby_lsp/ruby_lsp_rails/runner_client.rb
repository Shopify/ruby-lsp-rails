# typed: strict
# frozen_string_literal: true

require "json"
require "open3"

module RubyLsp
  module Rails
    class RunnerClient
      class << self
        extend T::Sig

        sig { returns(RunnerClient) }
        def create_client
          if File.exist?("bin/rails")
            new
          else
            $stderr.puts(<<~MSG)
              Ruby LSP Rails failed to locate bin/rails in the current directory: #{Dir.pwd}"
            MSG
            $stderr.puts("Server dependent features will not be available")
            NullClient.new
          end
        rescue Errno::ENOENT, StandardError => e # rubocop:disable Lint/ShadowedException
          $stderr.puts("Ruby LSP Rails failed to initialize server: #{e.message}\n#{e.backtrace&.join("\n")}")
          $stderr.puts("Server dependent features will not be available")
          NullClient.new
        end
      end

      class InitializationError < StandardError; end
      class IncompleteMessageError < StandardError; end
      class EmptyMessageError < StandardError; end

      MAX_RETRIES = 5

      extend T::Sig

      sig { returns(String) }
      attr_reader :rails_root

      sig { void }
      def initialize
        @mutex = T.let(Mutex.new, Mutex)
        # Spring needs a Process session ID. It uses this ID to "attach" itself to the parent process, so that when the
        # parent ends, the spring process ends as well. If this is not set, Spring will throw an error while trying to
        # set its own session ID
        begin
          Process.setpgrp
          Process.setsid
        rescue Errno::EPERM
          # If we can't set the session ID, continue
        rescue NotImplementedError
          # setpgrp() may be unimplemented on some platform
          # https://github.com/Shopify/ruby-lsp-rails/issues/348
        end

        stdin, stdout, stderr, wait_thread = Bundler.with_original_env do
          Open3.popen3("bundle", "exec", "rails", "runner", "#{__dir__}/server.rb", "start")
        end

        @stdin = T.let(stdin, IO)
        @stdout = T.let(stdout, IO)
        @stderr = T.let(stderr, IO)
        @wait_thread = T.let(wait_thread, Process::Waiter)

        # We set binmode for Windows compatibility
        @stdin.binmode
        @stdout.binmode
        @stderr.binmode

        $stderr.puts("Ruby LSP Rails booting server")
        count = 0

        begin
          count += 1
          initialize_response = T.must(read_response)
          @rails_root = T.let(initialize_response[:root], String)
        rescue EmptyMessageError
          $stderr.puts("Ruby LSP Rails is retrying initialize (#{count})")
          retry if count < MAX_RETRIES
        end

        $stderr.puts("Finished booting Ruby LSP Rails server")

        unless ENV["RAILS_ENV"] == "test"
          at_exit do
            if @wait_thread.alive?
              $stderr.puts("Ruby LSP Rails is force killing the server")
              sleep(0.5) # give the server a bit of time if we already issued a shutdown notification
              force_kill
            end
          end
        end
      rescue Errno::EPIPE, IncompleteMessageError
        raise InitializationError, @stderr.read
      end

      sig { params(server_addon_path: String).void }
      def register_server_addon(server_addon_path)
        send_notification("server_addon/register", server_addon_path: server_addon_path)
      rescue IncompleteMessageError
        $stderr.puts("Ruby LSP Rails failed to register server addon #{server_addon_path}")
        nil
      end

      sig { params(name: String).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def model(name)
        make_request("model", name: name)
      rescue IncompleteMessageError
        $stderr.puts("Ruby LSP Rails failed to get model information: #{@stderr.read}")
        nil
      end

      sig do
        params(
          model_name: String,
          association_name: String,
        ).returns(T.nilable(T::Hash[Symbol, T.untyped]))
      end
      def association_target_location(model_name:, association_name:)
        make_request(
          "association_target_location",
          model_name: model_name,
          association_name: association_name,
        )
      rescue => e
        $stderr.puts("Ruby LSP Rails failed with #{e.message}: #{@stderr.read}")
      end

      sig { params(name: String).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def route_location(name)
        make_request("route_location", name: name)
      rescue IncompleteMessageError
        $stderr.puts("Ruby LSP Rails failed to get route location: #{@stderr.read}")
        nil
      end

      sig { params(controller: String, action: String).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def route(controller:, action:)
        make_request("route_info", controller: controller, action: action)
      rescue IncompleteMessageError
        $stderr.puts("Ruby LSP Rails failed to get route information: #{@stderr.read}")
        nil
      end

      sig { void }
      def trigger_reload
        $stderr.puts("Reloading Rails application")
        send_notification("reload")
      rescue IncompleteMessageError
        $stderr.puts("Ruby LSP Rails failed to trigger reload")
        nil
      end

      sig { void }
      def shutdown
        $stderr.puts("Ruby LSP Rails shutting down server")
        send_message("shutdown")
        sleep(0.5) # give the server a bit of time to shutdown
        [@stdin, @stdout, @stderr].each(&:close)
      rescue IOError
        # The server connection may have died
        force_kill
      end

      sig { returns(T::Boolean) }
      def stopped?
        [@stdin, @stdout, @stderr].all?(&:closed?) && !@wait_thread.alive?
      end

      sig do
        params(
          request: String,
          params: T.nilable(T::Hash[Symbol, T.untyped]),
        ).returns(T.nilable(T::Hash[Symbol, T.untyped]))
      end
      def make_request(request, params = nil)
        send_message(request, params)
        read_response
      end

      # Notifications are like messages, but one-way, with no response sent back.
      sig { params(request: String, params: T.nilable(T::Hash[Symbol, T.untyped])).void }
      def send_notification(request, params = nil) = send_message(request, params)

      private

      sig { overridable.params(request: String, params: T.nilable(T::Hash[Symbol, T.untyped])).void }
      def send_message(request, params = nil)
        message = { method: request }
        message[:params] = params if params
        json = message.to_json

        @mutex.synchronize do
          @stdin.write("Content-Length: #{json.length}\r\n\r\n", json)
        end
      rescue Errno::EPIPE
        # The server connection died
      end

      sig { overridable.returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def read_response
        raw_response = @mutex.synchronize do
          headers = @stdout.gets("\r\n\r\n")
          raise IncompleteMessageError unless headers

          content_length = headers[/Content-Length: (\d+)/i, 1].to_i
          raise EmptyMessageError if content_length.zero?

          @stdout.read(content_length)
        end

        response = JSON.parse(T.must(raw_response), symbolize_names: true)

        if response[:error]
          $stderr.puts("Ruby LSP Rails error: " + response[:error])
          return
        end

        response.fetch(:result)
      rescue Errno::EPIPE
        # The server connection died
        nil
      end

      sig { void }
      def force_kill
        # Windows does not support the `TERM` signal, so we're forced to use `KILL` here
        Process.kill(T.must(Signal.list["KILL"]), @wait_thread.pid)
      end
    end

    class NullClient < RunnerClient
      extend T::Sig

      sig { void }
      def initialize # rubocop:disable Lint/MissingSuper
      end

      sig { override.void }
      def shutdown
        # no-op
      end

      sig { override.returns(T::Boolean) }
      def stopped?
        true
      end

      sig { override.returns(String) }
      def rails_root
        Dir.pwd
      end

      private

      sig { override.params(request: String, params: T.nilable(T::Hash[Symbol, T.untyped])).void }
      def send_message(request, params = nil)
        # no-op
      end

      sig { override.returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def read_response
        # no-op
      end
    end
  end
end
