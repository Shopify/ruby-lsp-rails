# typed: strict
# frozen_string_literal: true

require "rails/engine"
require "action_dispatch"

module RailsRubyLsp
  class Engine < ::Rails::Engine
    isolate_namespace RailsRubyLsp

    initializer "rails_ruby_lsp.routes" do
      config.after_initialize do |app|
        if Rails.env.development?
          app.routes.prepend do
            T.bind(self, ActionDispatch::Routing::Mapper)
            mount(RailsRubyLsp::Engine => "/rails_ruby_lsp")
          end
        end

        host = ENV.fetch("HOST") { "localhost" }
        port = ENV.fetch("PORT") { "3000" }

        File.write("#{Rails.root}/tmp/app_uri.txt", "http://#{host}:#{port}")
      end
    end
  end
end
