# typed: strict
# frozen_string_literal: true

require "json"
require "open3"

module RubyLsp
  module Rails
    class RunnerClient
      class << self
        #: (Thread::Queue outgoing_queue, RubyLsp::GlobalState global_state) -> RunnerClient
        def create_client(outgoing_queue, global_state)
          if File.exist?("bin/rails")
            new(outgoing_queue, global_state)
          else
            unless outgoing_queue.closed?
              outgoing_queue << RubyLsp::Notification.window_log_message(
                <<~MESSAGE.chomp,
                  Ruby LSP Rails failed to locate bin/rails in the current directory: #{Dir.pwd}
                  Server dependent features will not be available
                MESSAGE
                type: RubyLsp::Constant::MessageType::WARNING,
              )
            end

            NullClient.new
          end
        rescue StandardError => e
          unless outgoing_queue.closed?
            outgoing_queue << RubyLsp::Notification.window_log_message(
              <<~MESSAGE.chomp,
                Ruby LSP Rails failed to initialize server: #{e.full_message}
                Server dependent features will not be available
              MESSAGE
              type: Constant::MessageType::ERROR,
            )
          end

          NullClient.new
        end
      end

      class InitializationError < StandardError; end
      class MessageError < StandardError; end
      class EmptyMessageError < MessageError; end

      #: String
      attr_reader :rails_root

      #: (Thread::Queue outgoing_queue, RubyLsp::GlobalState global_state) -> void
      def initialize(outgoing_queue, global_state)
        @outgoing_queue = outgoing_queue #: Thread::Queue
        @mutex = Mutex.new #: Mutex

        log_message("Ruby LSP Rails booting server")

        stdin, stdout, stderr, wait_thread = Bundler.with_original_env do
          Open3.popen3(
            { "RUBY_LSP_RAILS_RUNNER" => "true" },
            "bundle",
            "exec",
            "rails",
            "runner",
            "#{__dir__}/server.rb",
            "start",
            server_relevant_capabilities(global_state),
          )
        end

        @stdin = stdin #: IO
        @stdout = stdout #: IO
        @stderr = stderr #: IO
        @stdin.sync = true
        @stdout.sync = true
        @stderr.sync = true
        @wait_thread = wait_thread #: Process::Waiter

        # We set binmode for Windows compatibility
        @stdin.binmode
        @stdout.binmode
        @stderr.binmode

        initialize_response = read_response #: as !nil
        @rails_root = initialize_response[:root] #: String
        log_message("Finished booting Ruby LSP Rails server")

        # Responsible for transmitting notifications coming from the server to the outgoing queue, so that we can do
        # things such as showing progress notifications initiated by the server. The loop exits naturally when the
        # server closes its stderr write end (i.e., when the server process exits), at which point `read_notification`
        # returns nil.
        @notifier_thread = Thread.new do
          while (notification = read_notification)
            @outgoing_queue << notification unless @outgoing_queue.closed?
          end
        end #: Thread
      rescue StandardError
        raise InitializationError, @stderr.read
      end

      #: (String server_addon_path) -> void
      def register_server_addon(server_addon_path)
        send_notification("server_addon/register", server_addon_path: server_addon_path)
      rescue MessageError
        log_message(
          "Ruby LSP Rails failed to register server addon #{server_addon_path}",
          type: RubyLsp::Constant::MessageType::ERROR,
        )
        nil
      end

      #: (String name) -> Hash[Symbol, untyped]?
      def model(name)
        make_request("model", name: name)
      rescue MessageError
        log_message(
          "Ruby LSP Rails failed to get model information",
          type: RubyLsp::Constant::MessageType::ERROR,
        )
        nil
      end

      #: (model_name: String, association_name: String) -> Hash[Symbol, untyped]?
      def association_target(model_name:, association_name:)
        make_request(
          "association_target",
          model_name: model_name,
          association_name: association_name,
        )
      rescue MessageError
        log_message(
          "Ruby LSP Rails failed to get association location",
          type: RubyLsp::Constant::MessageType::ERROR,
        )
        nil
      end

      #: (String name) -> Hash[Symbol, untyped]?
      def route_location(name)
        make_request("route_location", name: name)
      rescue MessageError
        log_message(
          "Ruby LSP Rails failed to get route location",
          type: RubyLsp::Constant::MessageType::ERROR,
        )
        nil
      end

      #: (controller: String, action: String) -> Hash[Symbol, untyped]?
      def route(controller:, action:)
        make_request("route_info", controller: controller, action: action)
      rescue MessageError
        log_message(
          "Ruby LSP Rails failed to get route information",
          type: RubyLsp::Constant::MessageType::ERROR,
        )
        nil
      end

      #: (String key) -> Hash[Symbol, untyped]?
      def i18n(key)
        make_request("i18n", key: key)
      rescue MessageError
        log_message(
          "Ruby LSP Rails failed to get i18n information",
          type: RubyLsp::Constant::MessageType::ERROR,
        )
        nil
      end

      # Delegates a notification to a server add-on
      #: (server_addon_name: String, request_name: String, **untyped params) -> void
      def delegate_notification(server_addon_name:, request_name:, **params)
        send_notification(
          "server_addon/delegate",
          request_name: request_name,
          server_addon_name: server_addon_name,
          **params,
        )
      end

      #: -> String?
      def pending_migrations_message
        response = make_request("pending_migrations_message")
        response[:pending_migrations_message] if response
      rescue MessageError
        log_message(
          "Ruby LSP Rails failed when checking for pending migrations",
          type: RubyLsp::Constant::MessageType::ERROR,
        )
        nil
      end

      #: -> Hash[Symbol, untyped]?
      def run_migrations
        make_request("run_migrations")
      rescue MessageError
        log_message(
          "Ruby LSP Rails failed to run migrations",
          type: RubyLsp::Constant::MessageType::ERROR,
        )
        nil
      end

      # Delegates a request to a server add-on
      #: (server_addon_name: String, request_name: String, **untyped params) -> Hash[Symbol, untyped]?
      def delegate_request(server_addon_name:, request_name:, **params)
        make_request(
          "server_addon/delegate",
          server_addon_name: server_addon_name,
          request_name: request_name,
          **params,
        )
      rescue MessageError
        nil
      end

      #: -> void
      def trigger_reload
        log_message("Reloading Rails application")
        send_notification("reload")
      rescue MessageError
        log_message(
          "Ruby LSP Rails failed to trigger reload",
          type: RubyLsp::Constant::MessageType::ERROR,
        )
        nil
      end

      #: -> void
      def trigger_i18n_reload
        log_message("Reloading I18n translations")
        send_notification("reload_i18n")
      rescue MessageError
        log_message(
          "Ruby LSP Rails failed to trigger I18n reload",
          type: RubyLsp::Constant::MessageType::ERROR,
        )
        nil
      end

      SHUTDOWN_DIAGNOSTIC_TIMEOUT = 10 #: Integer

      #: -> void
      def shutdown
        return if stopped?

        log_message("Ruby LSP Rails shutting down server")
        send_message("shutdown")

        @stdin.close unless @stdin.closed?

        # Wait for the server to exit. Once it does, all handles it inherited (including its stderr write end) are
        # released, which lets the notifier thread drain remaining bytes and observe EOF.
        unless @wait_thread.join(SHUTDOWN_DIAGNOSTIC_TIMEOUT)
          dump_shutdown_diagnostics("wait_thread did not exit within #{SHUTDOWN_DIAGNOSTIC_TIMEOUT}s")
          @wait_thread.join
        end

        unless @notifier_thread.join(SHUTDOWN_DIAGNOSTIC_TIMEOUT)
          dump_shutdown_diagnostics("notifier_thread did not exit within #{SHUTDOWN_DIAGNOSTIC_TIMEOUT}s")
          @notifier_thread.join
        end

        @stdout.close unless @stdout.closed?
        @stderr.close unless @stderr.closed?
      end

      #: -> bool
      def stopped?
        [@stdin, @stdout, @stderr].all?(&:closed?) && !@wait_thread.alive? && !@notifier_thread.alive?
      end

      #: -> bool
      def connected?
        true
      end

      private

      #: (String request, **untyped params) -> Hash[Symbol, untyped]?
      def make_request(request, **params)
        send_message(request, **params)
        read_response
      end

      # Notifications are like messages, but one-way, with no response sent back.
      #: (String request, **untyped params) -> void
      def send_notification(request, **params) = send_message(request, **params)

      # Print state of the shutdown machinery to stderr so a stuck CI run leaves a forensic record before timing out at
      # the job level. Prints once per stuck join — does not abort the wait. Visible in the parent process's stderr,
      # which CI captures.
      #: (String) -> void
      def dump_shutdown_diagnostics(stage)
        warn("[ruby-lsp-rails shutdown] #{stage}")
        warn("  wait_thread alive=#{@wait_thread.alive?} status=#{@wait_thread.status.inspect}")
        warn("  notifier_thread alive=#{@notifier_thread.alive?} status=#{@notifier_thread.status.inspect}")
        warn("  stdin closed=#{@stdin.closed?} stdout closed=#{@stdout.closed?} stderr closed=#{@stderr.closed?}")

        if @notifier_thread.alive?
          backtrace = @notifier_thread.backtrace
          warn("  notifier_thread backtrace:")
          backtrace&.each { |line| warn("    #{line}") }
        end
      end

      # @overridable
      #: (String request, **untyped params) -> void
      def send_message(request, **params)
        message = { method: request }
        message[:params] = params
        json = message.to_json

        @mutex.synchronize do
          @stdin.write("Content-Length: #{json.bytesize}\r\n\r\n", json)
        end
      rescue Errno::EPIPE
        # The server connection died
      end

      # @overridable
      #: -> Hash[Symbol, untyped]?
      def read_response
        raw_response = @mutex.synchronize do
          content_length = read_content_length
          content_length = read_content_length unless content_length
          raise EmptyMessageError unless content_length

          @stdout.read(content_length)
        end #: as !nil

        response = JSON.parse(raw_response, symbolize_names: true)

        if response[:error]
          log_message(
            "Ruby LSP Rails error: #{response[:error]}",
            type: RubyLsp::Constant::MessageType::ERROR,
          )
          return
        end

        response.fetch(:result)
      rescue Errno::EPIPE
        # The server connection died
        nil
      end

      #: (::String message, ?type: ::Integer) -> void
      def log_message(message, type: RubyLsp::Constant::MessageType::LOG)
        return if @outgoing_queue.closed?

        @outgoing_queue << RubyLsp::Notification.window_log_message(message, type: type)
      end

      #: -> Integer?
      def read_content_length
        headers = @stdout.gets("\r\n\r\n")
        return unless headers

        length = headers[/Content-Length: (\d+)/i, 1]
        return unless length

        length.to_i
      end

      # Read a server notification from stderr. Only intended to be used by notifier thread
      #: -> Hash[Symbol, untyped]?
      def read_notification
        headers = @stderr.gets("\r\n\r\n")
        return unless headers

        length = headers[/Content-Length: (\d+)/i, 1]
        return unless length

        raw_content = @stderr.read(length.to_i)
        return unless raw_content

        JSON.parse(raw_content, symbolize_names: true)
      end

      #: (GlobalState global_state) -> String
      def server_relevant_capabilities(global_state)
        {
          supports_progress: global_state.client_capabilities.supports_progress,
        }.to_json
      end
    end

    class NullClient < RunnerClient
      #: -> void
      def initialize # rubocop:disable Lint/MissingSuper
      end

      # @override
      #: -> void
      def shutdown
        # no-op
      end

      # @override
      #: -> bool
      def stopped?
        true
      end

      # @override
      #: -> String
      def rails_root
        Dir.pwd
      end

      #: -> bool
      def connected?
        false
      end

      private

      #: (::String message, ?type: ::Integer) -> void
      def log_message(message, type: RubyLsp::Constant::MessageType::LOG)
        # no-op
      end

      # @override
      #: (String request, **untyped params) -> void
      def send_message(request, **params)
        # no-op
      end

      # @override
      #: -> Hash[Symbol, untyped]?
      def read_response
        # no-op
      end
    end
  end
end
