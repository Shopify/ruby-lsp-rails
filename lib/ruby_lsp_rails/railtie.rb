# typed: strict
# frozen_string_literal: true

require "rails"
require "ruby_lsp_rails/rack_app"

module RubyLsp
  module Rails
    class Railtie < ::Rails::Railtie
      config.ruby_lsp_rails = ActiveSupport::OrderedOptions.new
      config.ruby_lsp_rails.server = true

      initializer "ruby_lsp_rails.setup" do |app|
        next unless config.ruby_lsp_rails.server

        # NOTE: We want to insert after Rails::Rack::Logger to bypass further
        # middleware like ones that check migrations and interrupt the request.
        app.middleware.insert_after(::Rails::Rack::Logger, RackApp)

        config.after_initialize do
          # If we start the app with `bin/rails console` then `Rails::Server` is not defined.
          if defined?(::Rails::Server)
            ssl_enable, host, port = ::Rails::Server::Options.new.parse!(ARGV).values_at(:SSLEnable, :Host, :Port)
            app_uri = "#{ssl_enable ? "https" : "http"}://#{host}:#{port}"
            app_uri_path = ::Rails.root.join("tmp", "app_uri.txt")
            app_uri_path.write(app_uri)

            at_exit do
              # The app_uri.txt file should only exist when the server is running. The addon uses its presence to
              # report if the server is running or not. If the server is not running, some of the addon features
              # will not be available.
              File.delete(app_uri_path) if File.exist?(app_uri_path)
            end
          end
        end
      end
    end
  end
end
