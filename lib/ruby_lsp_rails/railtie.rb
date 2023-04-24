# typed: strict
# frozen_string_literal: true

require "rails/railtie"
require "ruby_lsp_rails/middleware"

module RubyLsp
  module Rails
    class Railtie < ::Rails::Railtie
      initializer "ruby_lsp_rails.setup" do |app|
        app.config.middleware.insert_after(ActionDispatch::ShowExceptions, RubyLsp::Rails::Middleware)

        config.after_initialize do |_app|
          if defined?(::Rails::Server)
            ssl_enable, host, port = ::Rails::Server::Options.new.parse!(ARGV).values_at(:SSLEnable, :Host, :Port)
            app_uri = "#{ssl_enable ? "https" : "http"}://#{host}:#{port}"
            File.write("#{::Rails.root}/tmp/app_uri.txt", app_uri)
          end
        end
      end
    end
  end
end
