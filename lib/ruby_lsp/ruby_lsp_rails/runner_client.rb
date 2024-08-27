# typed: strict
# frozen_string_literal: true

require "json"
require "open3"
require "ruby_lsp/addon/process_client"

module RubyLsp
  module Rails
    class RunnerClient < RubyLsp::Addon::ProcessClient
      COMMAND = T.let(["bundle", "exec", "rails", "runner", "#{__dir__}/server.rb", "start"].join(" "), String)

      class << self
        extend T::Sig

        sig { params(addon: RubyLsp::Addon).returns(RunnerClient) }
        def create_client(addon)
          if File.exist?("bin/rails")
            new(addon, COMMAND)
          else
            $stderr.puts(<<~MSG)
              Ruby LSP Rails failed to locate bin/rails in the current directory: #{Dir.pwd}"
            MSG
            $stderr.puts("Server dependent features will not be available")
            NullClient.new(addon)
          end
        rescue Errno::ENOENT, StandardError => e # rubocop:disable Lint/ShadowedException
          $stderr.puts("Ruby LSP Rails failed to initialize server: #{e.message}\n#{e.backtrace&.join("\n")}")
          $stderr.puts("Server dependent features will not be available")
          NullClient.new(addon)
        end
      end

      extend T::Sig

      sig { returns(String) }
      def rails_root
        T.must(@rails_root)
      end

      sig { params(message: String).void }
      def log_output(message)
        # We don't want to log output in tests
        unless ENV["RAILS_ENV"] == "test"
          super
        end
      end
      sig { override.params(response: T::Hash[Symbol, T.untyped]).void }
      def handle_initialize_response(response)
        @rails_root = T.let(response[:root], T.nilable(String))
      end

      sig { override.void }
      def register_exit_handler
        unless ENV["RAILS_ENV"] == "test"
          at_exit do
            if wait_thread.alive?
              log_output("force killing the server")
              sleep(0.5) # give the server a bit of time if we already issued a shutdown notification
              force_kill
            end
          end
        end
      end

      sig { params(name: String).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def model(name)
        make_request("model", name: name)
      rescue IncompleteMessageError
        log_output("failed to get model information: #{stderr.read}")
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
        log_output("failed with #{e.message}: #{stderr.read}")
        nil
      end

      sig { params(name: String).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def route_location(name)
        make_request("route_location", name: name)
      rescue IncompleteMessageError
        log_output("failed to get route location: #{stderr.read}")
        nil
      end

      sig { params(controller: String, action: String).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def route(controller:, action:)
        make_request("route_info", controller: controller, action: action)
      rescue IncompleteMessageError
        log_output("failed to get route information: #{stderr.read}")
        nil
      end

      sig { void }
      def trigger_reload
        log_output("triggering reload")
        send_notification("reload")
      rescue IncompleteMessageError
        log_output("failed to trigger reload")
        nil
      end
    end

    class NullClient < RunnerClient
      extend T::Sig

      sig { params(addon: RubyLsp::Addon).void }
      def initialize(addon) # rubocop:disable Lint/MissingSuper
        @addon = addon
      end

      sig { override.params(response: T::Hash[Symbol, T.untyped]).void }
      def handle_initialize_response(response)
        # no-op
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
