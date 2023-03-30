# typed: strict
# frozen_string_literal: true

require_relative "rails_client"
require_relative "hover"

module RailsRubyLsp
  module RubyLsp
    class Extension < ::RubyLsp::Extensions::Base
      class << self
        extend T::Sig

        sig { override.void }
        def activate
          # Must be the last statement in activate since it raises to display a notification for the user
          RailsRubyLsp::RailsClient.instance.check_if_server_is_running!
        end
      end
    end
  end
end
