# typed: strict
# frozen_string_literal: true

require "singleton"
require "net/http"

module RubyLsp
  module Rails
    class RailsClient
      class ServerAddressUnknown < StandardError; end

      extend T::Sig
      include Singleton

      SERVER_NOT_RUNNING_MESSAGE = "Rails server is not running. " \
        "To get Rails features in the editor, boot the Rails server"

      sig { returns(String) }
      attr_reader :root

      sig { void }
      def initialize
        project_root = Pathname.new(ENV["BUNDLE_GEMFILE"]).dirname

        if project_root.basename.to_s == ".ruby-lsp"
          project_root = project_root.join("../")
        end

        dummy_path = File.join(project_root, "test", "dummy")
        @root = T.let(Dir.exist?(dummy_path) ? dummy_path : project_root.to_s, String)
        app_uri_path = "#{@root}/tmp/app_uri.txt"

        if File.exist?(app_uri_path)
          url = File.read(app_uri_path).chomp

          scheme, rest = url.split("://")
          uri, port = T.must(rest).split(":")

          @ssl = T.let(scheme == "https", T::Boolean)
          @uri = T.let(T.must(uri), T.nilable(String))
          @port = T.let(T.must(port).to_i, Integer)
        end
      end

      sig { params(name: String).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def model(name)
        response = request("models/#{name}")
        return unless response.code == "200"

        JSON.parse(response.body.chomp, symbolize_names: true)
      rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, Net::ReadTimeout, ServerAddressUnknown
        nil
      end

      sig { void }
      def check_if_server_is_running!
        request("activate", 0.2)
      rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, ServerAddressUnknown
        warn(SERVER_NOT_RUNNING_MESSAGE)
      rescue Net::ReadTimeout
        # If the server is running, but the initial request is taking too long, we don't want to block the
        # initialization of the Ruby LSP
      end

      private

      sig { params(path: String, timeout: T.nilable(Float)).returns(Net::HTTPResponse) }
      def request(path, timeout = nil)
        raise ServerAddressUnknown unless @uri

        http = Net::HTTP.new(@uri, @port)
        http.use_ssl = @ssl
        http.read_timeout = timeout if timeout
        http.get("/ruby_lsp_rails/#{path}")
      end
    end
  end
end
