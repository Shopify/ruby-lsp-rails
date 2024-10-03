# typed: false
# frozen_string_literal: true

# requiring sorbet-runtime in the server can lead to some problems, so this is untyped
# https://github.com/Shopify/ruby-lsp-rails/pull/469#issuecomment-2391429546

module RubyLsp
  module Rails
    class ServerAddon
      @server_addon_classes = []
      @server_addons = {}

      class << self
        # We keep track of runtime server add-ons the same way we track other add-ons, by storing
        # classes that inherit from the base one
        def inherited(child)
          @server_addon_classes << child
          super
        end

        # Delegate `request` with `params` to the server add-on with the given `name`
        def delegate(name, request, params)
          @server_addons[name]&.execute(request, params)
        end

        # Instantiate all server addons and store them in a hash for easy access after we have discovered the classes
        def finalize_registrations!(stdout)
          until @server_addon_classes.empty?
            addon = @server_addon_classes.shift.new(stdout)
            @server_addons[addon.name] = addon
          end
        end
      end

      def initialize(stdout)
        @stdout = stdout
      end

      # Write a response back. Can be used for sending notifications to the editor
      def write_response(response)
        json_response = response.to_json
        @stdout.write("Content-Length: #{json_response.length}\r\n\r\n#{json_response}")
      end

      def name
        raise NotImplementedError, "Not implemented!"
      end

      def execute(request, params)
        raise NotImplementedError, "Not implemented!"
      end
    end
  end
end
