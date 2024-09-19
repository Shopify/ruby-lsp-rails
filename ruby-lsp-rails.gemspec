# frozen_string_literal: true

require_relative "lib/ruby_lsp_rails/version"

Gem::Specification.new do |spec|
  spec.name        = "ruby-lsp-rails"
  spec.version     = RubyLsp::Rails::VERSION
  spec.authors     = ["Shopify"]
  spec.email       = ["ruby@shopify.com"]
  spec.homepage    = "https://github.com/Shopify/ruby-lsp-rails"
  spec.summary     = "A Ruby LSP addon for Rails"
  spec.description = "A Ruby LSP addon that adds extra editor functionality for Rails applications"
  spec.license     = "MIT"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"
  spec.metadata["documentation_uri"] = "https://shopify.github.io/ruby-lsp/rails-addon.html"

  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/**/*", "LICENSE.txt", "Rakefile", "README.md"]
  end

  spec.add_dependency("ruby-lsp", ">= 0.18.0", "< 0.19.0")
end
