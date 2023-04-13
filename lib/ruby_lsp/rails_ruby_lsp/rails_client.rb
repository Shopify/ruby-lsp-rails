# typed: strict
# frozen_string_literal: true

require "singleton"
require "net/http"

module RailsRubyLsp
  class RailsClient
    class ServerNotRunningError < StandardError; end

    extend T::Sig
    include Singleton

    SERVER_NOT_RUNNING_MESSAGE = "Rails server is not running. " \
      "To get Rails features in the editor, boot the Rails server"

    sig { returns(String) }
    attr_reader :root

    sig { void }
    def initialize
      @root = T.let(Dir.exist?("test/dummy") ? File.join(Dir.pwd, "test", "dummy") : Dir.pwd, String)
      base_uri = File.read("#{@root}/tmp/app_uri.txt").chomp

      @uri = T.let("#{base_uri}/rails_ruby_lsp", String)
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
