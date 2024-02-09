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

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE.txt", "Rakefile", "README.md"]
  end

  spec.add_dependency("actionpack", ">= 6.0")
  spec.add_dependency("activerecord", ">= 6.0")
  spec.add_dependency("railties", ">= 6.0")
  spec.add_dependency("ruby-lsp", ">= 0.13.0")
  spec.add_dependency("sorbet-runtime", ">= 0.5.9897")
end
