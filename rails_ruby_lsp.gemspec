# frozen_string_literal: true

require_relative "lib/rails_ruby_lsp/version"

Gem::Specification.new do |spec|
  spec.name        = "rails_ruby_lsp"
  spec.version     = RailsRubyLsp::VERSION
  spec.authors     = ["Shopify"]
  spec.email       = ["ruby@shopify.com"]
  spec.homepage    = "https://github.com/Shopify/rails_ruby_lsp"
  spec.summary     = "A Ruby LSP extension for Rails"
  spec.description = "A Ruby LSP extension that adds extra editor functionality for Rails applications"
  spec.license     = "MIT"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE.txt", "Rakefile", "README.md"]
  end

  spec.add_dependency("rails", ">= 6.0")
  spec.add_dependency("ruby-lsp", ">= 0.4.0")
  spec.add_dependency("sorbet-runtime", ">= 0.5.9897")
end
