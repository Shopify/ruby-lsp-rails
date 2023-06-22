# typed: strict
# frozen_string_literal: true

require "rails/railtie"
require "ruby_lsp_rails/middleware"

module RubyLsp
  module Rails
    class Railtie < ::Rails::Railtie
      initializer "ruby_lsp_rails.setup" do |app|
        app.config.middleware.insert_before(ActionDispatch::Static, RubyLsp::Rails::Middleware)

        config.after_initialize do |_app|
          if defined?(::Rails::Server)
            ssl_enable, host, port = ::Rails::Server::Options.new.parse!(ARGV).values_at(:SSLEnable, :Host, :Port)
            app_uri = "#{ssl_enable ? "https" : "http"}://#{host}:#{port}"
            app_uri_path = "#{::Rails.root}/tmp/app_uri.txt"
            File.write(app_uri_path, app_uri)

            at_exit do
              # The app_uri.txt file should only exist when the server is running. The extension uses its presence to
              # report if the server is running or not. If the server is not running, some of the extension features
              # will not be available.
              File.delete(app_uri_path) if File.exist?(app_uri_path)
            end
          end
        end
      end
    end
  end
end
