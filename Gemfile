# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in rails_ruby_lsp.gemspec.
gemspec

gem "puma"
gem "sqlite3"
gem "debug", ">= 1.7.0"
gem "rubocop", "~> 1.48", require: false
gem "rubocop-shopify", "~> 2.12", require: false
gem "rubocop-minitest", "~> 0.29.0", require: false
gem "rubocop-rake", "~> 0.6.0", require: false
gem "rubocop-sorbet", "~> 0.7", require: false

gem "sorbet-static-and-runtime"
gem "tapioca", "~> 0.11", require: false

# TODO: stop pointing at main on the next Ruby LSP release
gem "ruby-lsp", github: "Shopify/ruby-lsp", branch: "main"
