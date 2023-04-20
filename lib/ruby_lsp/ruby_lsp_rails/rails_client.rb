# typed: strict
# frozen_string_literal: true

require "singleton"
require "net/http"

module RubyLsp
  module Rails
    class RailsClient
      class ServerNotRunningError < StandardError; end
      class NeedsRestartError < StandardError; end

      extend T::Sig
      include Singleton

      SERVER_NOT_RUNNING_MESSAGE = "Rails server is not running. " \
        "To get Rails features in the editor, boot the Rails server"

      sig { returns(String) }
      attr_reader :root

      sig { void }
      def initialize
        project_root = Pathname.new(ENV["BUNDLE_GEMFILE"]).dirname
        dummy_path = File.join(project_root, "test", "dummy")
        @root = T.let(Dir.exist?(dummy_path) ? dummy_path : project_root.to_s, String)
        app_uri_path = "#{@root}/tmp/app_uri.txt"

        unless File.exist?(app_uri_path)
          raise NeedsRestartError, <<~MESSAGE
            The Ruby LSP Rails extension needs to be initialized. Please restart the Rails server and the Ruby LSP
            to get Rails features in the editor
          MESSAGE
        end

        base_uri = File.read(app_uri_path).chomp
        @uri = T.let("#{base_uri}/ruby_lsp_rails", String)
      end

      sig { params(name: String).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def model(name)
        response = request("models/#{name}")
        return unless response.code == "200"

        JSON.parse(response.body.chomp, symbolize_names: true)
      rescue Errno::ECONNREFUSED
        raise ServerNotRunningError, SERVER_NOT_RUNNING_MESSAGE
      end

      sig { void }
      def check_if_server_is_running!
        # Check if the Rails server is running. Warn the user to boot it for Rails features
        pid_file = ENV.fetch("PIDFILE") { File.join(@root, "tmp", "pids", "server.pid") }

        # If the PID file doesn't exist, then the server hasn't been booted
        raise ServerNotRunningError, SERVER_NOT_RUNNING_MESSAGE unless File.exist?(pid_file)

        pid = File.read(pid_file).to_i

        begin
          # Issuing an EXIT signal to an existing process actually doesn't make the server shutdown. But if this
          # call succeeds, then the server is running. If the PID doesn't exist, Errno::ESRCH is raised
          Process.kill(T.must(Signal.list["EXIT"]), pid)
        rescue Errno::ESRCH
          raise ServerNotRunningError, SERVER_NOT_RUNNING_MESSAGE
        end
      end

      private

      sig { params(path: String).returns(Net::HTTPResponse) }
      def request(path)
        Net::HTTP.get_response(URI("#{@uri}/#{path}"))
      end
    end
  end
end
