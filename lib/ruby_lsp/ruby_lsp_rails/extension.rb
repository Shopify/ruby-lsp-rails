# typed: strict
# frozen_string_literal: true

require "ruby_lsp/extension"

require_relative "rails_client"
require_relative "hover"
require_relative "code_lens"

module RubyLsp
  module Rails
    class Extension < ::RubyLsp::Extension
      extend T::Sig

      sig { override.void }
      def activate
        ::RubyLsp::Requests::Hover.add_listener(RubyLsp::Rails::Hover)
        ::RubyLsp::Requests::CodeLens.add_listener(RubyLsp::Rails::CodeLens)

        RubyLsp::Rails::RailsClient.instance.check_if_server_is_running!
      end

      sig { override.returns(String) }
      def name
        "Ruby LSP Rails"
      end
    end
  end
end
