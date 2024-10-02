# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module RubyLsp
  module Rails
    class ServerAddon
      extend T::Sig
      extend T::Helpers

      abstract!

      @server_addon_classes = T.let([], T::Array[T.class_of(ServerAddon)])
      @server_addons = T.let({}, T::Hash[String, ServerAddon])

      module Types
        Params = T.type_alias { T::Hash[T.untyped, T.untyped] }
        Response = T.type_alias { T::Hash[Symbol, T.untyped] }
      end

      class << self
        extend T::Sig

        # We keep track of runtime server add-ons the same way we track other add-ons, by storing
        # classes that inherit from the base one
        sig { params(child: T::Class[T.anything]).void }
        def inherited(child)
          @server_addon_classes << T.cast(child, T.class_of(ServerAddon))
          super
        end

        # Delegate `request` with `params` to the server add-on with the given `name`
        sig { params(name: String, request: String, params: Types::Params).returns(T.nilable(Types::Response)) }
        def delegate(name, request, params)
          @server_addons[name]&.execute(request, params)
        end

        # Instantiate all server addons and store them in a hash for easy access after we have discovered the classes
        sig { params(stdout: T.any(IO, StringIO)).void }
        def finalize_registrations!(stdout)
          until @server_addon_classes.empty?
            addon = T.must(@server_addon_classes.shift).new(stdout)
            @server_addons[addon.name] = addon
          end
        end
      end

      sig { params(stdout: T.any(IO, StringIO)).void }
      def initialize(stdout)
        @stdout = stdout
      end

      # Write a response back. Can be used for sending notifications to the editor
      sig { params(response: Types::Response).void }
      def write_response(response)
        json_response = response.to_json
        @stdout.write("Content-Length: #{json_response.length}\r\n\r\n#{json_response}")
      end

      sig { abstract.returns(String) }
      def name
      end

      sig { abstract.params(request: String, params: Types::Params).returns(Types::Response) }
      def execute(request, params)
      end
    end
  end
end
