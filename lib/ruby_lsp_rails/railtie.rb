# typed: strict
# frozen_string_literal: true

require "rails"

module RubyLsp
  module Rails
    class Railtie < ::Rails::Railtie
      config.ruby_lsp_rails = ActiveSupport::OrderedOptions.new

      initializer "ruby_lsp_rails.setup" do |_app|
        config.after_initialize do |_app|
          unless config.ruby_lsp_rails.server.nil?
            ActiveSupport::Deprecation.new.warn("The `ruby_lsp_rails.server` configuration option is no longer " \
              "needed and will be removed in a future release.")
          end
        end
      end
    end
  end
end
