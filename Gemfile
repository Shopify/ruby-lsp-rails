# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in ruby_lsp_rails.gemspec.
gemspec

gem "puma"
gem "sqlite3"
gem "debug", ">= 1.7.0"
gem "mocha"
gem "rubocop-shopify", "~> 2.15", require: false
gem "rubocop-minitest", "~> 0.36.0", require: false
gem "rubocop-rake", "~> 0.6.0", require: false
gem "rubocop-sorbet", "~> 0.8", require: false
gem "sorbet-static-and-runtime", platforms: :ruby
# gem "tapioca", "~> 0.13", require: false, platforms: :ruby
gem "psych", "~> 5.1", require: false
gem "rails", "8.0.0"

platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo"
  gem "tzinfo-data"
end

gem "ruby-lsp", path: "../ruby-lsp"
