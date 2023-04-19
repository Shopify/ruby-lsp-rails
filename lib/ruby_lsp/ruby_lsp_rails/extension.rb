# typed: strict
# frozen_string_literal: true

require "ruby_lsp/extension"

require_relative "rails_client"
require_relative "hover"

module RubyLsp
  module Rails
    class Extension < ::RubyLsp::Extension
      extend T::Sig

      sig { override.void }
      def activate
        # Must be the last statement in activate since it raises to display a notification for the user
        RubyLsp::Rails::RailsClient.instance.check_if_server_is_running!
      end

      sig { override.returns(String) }
      def name
        "Ruby LSP Rails"
      end
    end
  end
end
