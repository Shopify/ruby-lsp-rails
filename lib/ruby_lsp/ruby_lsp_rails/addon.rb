# typed: strict
# frozen_string_literal: true

require "ruby_lsp/addon"

require_relative "rails_client"
require_relative "hover"
require_relative "code_lens"
require "open3"

module RubyLsp
  module Rails
    class Addon < ::RubyLsp::Addon
      extend T::Sig

      sig { returns(RailsClient) }
      def client
        @client ||= T.let(RailsClient.new, T.nilable(RailsClient))
      end

      sig { override.params(message_queue: Thread::Queue).void }
      def activate(message_queue)
        client.check_if_server_is_running!
        @stdin, @stdout, @stderr, @wait_thread = Open3.popen3("bin/rails", "runner", "#{__dir__}/server.rb")

        @stdin.binmode
        @stdout.binmode
      end

      sig { override.void }
      def deactivate
        send_request("shutdown")

        @stdin.close
        @stdout.close
        @stderr.close
      end

      def make_request(request, params = nil)
        send_request(request, params)
        read_response(request)
      end

      def send_request(request, params = nil)
        hash = {
          method: request,
        }

        hash[:params] = params if params
        json = hash.to_json
        @stdin.write("Content-Length: #{json.length}\r\n\r\n", json)
      end

      def read_response(request)
        Timeout.timeout(5) do
          # Read headers until line breaks
          headers = @stdout.gets("\r\n\r\n")

          # Read the response content based on the length received in the headers
          raw_response = @stdout.read(headers[/Content-Length: (\d+)/i, 1].to_i)

          json = JSON.parse(raw_response, symbolize_names: true)
          warn("*** response ***: #{json}")
        end
      rescue Timeout::Error
        raise "Request #{request} timed out. Is the request returning a response?"
      end

      # Creates a new CodeLens listener. This method is invoked on every CodeLens request
      sig do
        override.params(
          uri: URI::Generic,
          dispatcher: Prism::Dispatcher,
        ).returns(T.nilable(Listener[T::Array[Interface::CodeLens]]))
      end
      def create_code_lens_listener(uri, dispatcher)
        CodeLens.new(uri, dispatcher)
      end

      sig do
        override.params(
          nesting: T::Array[String],
          index: RubyIndexer::Index,
          dispatcher: Prism::Dispatcher,
        ).returns(T.nilable(Listener[T.nilable(Interface::Hover)]))
      end
      def create_hover_listener(nesting, index, dispatcher)
        Hover.new(client, nesting, index, dispatcher)
      end

      sig { override.returns(String) }
      def name
        "Ruby LSP Rails"
      end
    end
  end
end
