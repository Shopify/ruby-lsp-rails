# typed: strict
# frozen_string_literal: true

require "rails/engine"
require "action_dispatch"

module RailsRubyLsp
  class Engine < ::Rails::Engine
    isolate_namespace RailsRubyLsp
  end
end
