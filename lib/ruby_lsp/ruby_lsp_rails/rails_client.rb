# typed: strict
# frozen_string_literal: true

require "net/http"

module RubyLsp
  module Rails
    class RailsClient
      class ServerAddressUnknown < StandardError; end

      extend T::Sig

      SERVER_NOT_FOUND_ERRORS = T.let(
        [
          Errno::ECONNREFUSED,
          Errno::EADDRNOTAVAIL,
          Errno::ECONNRESET,
          ServerAddressUnknown,
        ],
        T::Array[T.class_of(Exception)],
      )

      SERVER_TIMEOUT_ERRORS = T.let(
        [
          Net::ReadTimeout,
          Net::OpenTimeout,
        ],
        T::Array[T.class_of(Exception)],
      )

      SERVER_UNAVAILABLE_ERRORS = T.let(
        [
          *SERVER_NOT_FOUND_ERRORS, *SERVER_TIMEOUT_ERRORS,
        ],
        T::Array[T.class_of(Exception)],
      )

      SERVER_NOT_RUNNING_MESSAGE = "Rails server is not running. " \
        "To get Rails features in the editor, boot the Rails server"

      class << self
        extend T::Sig

        sig { returns(Pathname) }
        def root
          @root ||= T.let(
            Bundler.with_unbundled_env { Bundler.default_gemfile }.dirname,
            T.nilable(Pathname),
          )
        end

        sig { params(root: Pathname).void }
        attr_writer :root
      end

      sig { void }
      def initialize
        app_uri_path = root.join("tmp", "app_uri.txt")

        if app_uri_path.exist?
          url = URI(app_uri_path.read.chomp)

          @ssl = T.let(url.scheme == "https", T::Boolean)
          @address = T.let(
            [url.host, url.path].reject { |component| component.nil? || component.empty? }.join("/"),
            T.nilable(String),
          )
          @port = T.let(T.must(url.port).to_i, Integer)
        end
      end

      sig { params(name: String).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def model(name)
        response = request("models/#{name}")
        return unless response.code == "200"

        JSON.parse(response.body.chomp, symbolize_names: true)
      rescue *SERVER_UNAVAILABLE_ERRORS
        nil
      end

      sig { params(controller: String, action: String).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def route(controller:, action:)
        response = request("route?controller=#{controller}&action=#{action}")
        return unless response.code == "200"

        JSON.parse(response.body.chomp, symbolize_names: true)
      rescue *SERVER_UNAVAILABLE_ERRORS
        nil
      end

      sig { void }
      def check_if_server_is_running!
        request("activate", 0.2)
      rescue *SERVER_NOT_FOUND_ERRORS
        warn(SERVER_NOT_RUNNING_MESSAGE)
      rescue *SERVER_TIMEOUT_ERRORS
        # If the server is running, but the initial request is taking too long, we don't want to block the
        # initialization of the Ruby LSP
      end

      sig { returns(Pathname) }
      def root
        self.class.root
      end

      private

      sig { params(path: String, timeout: T.nilable(Float)).returns(Net::HTTPResponse) }
      def request(path, timeout = nil)
        raise ServerAddressUnknown unless @address

        http = Net::HTTP.new(@address, @port)
        http.use_ssl = @ssl
        http.read_timeout = timeout if timeout
        http.get("/ruby_lsp_rails/#{path}")
      end
    end
  end
end
