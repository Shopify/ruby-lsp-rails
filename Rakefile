# frozen_string_literal: true

require "bundler/setup"

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)

load "rails/tasks/engine.rake"
load "rails/tasks/statistics.rake"

require "bundler/gem_tasks"
require "rake/testtask"
require "ruby_lsp/check_docs"
require "rdoc/task"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

RDoc::Task.new do |rdoc|
  rdoc.main = "README.md"
  rdoc.rdoc_files.include("*.md", "lib/**/*.rb")
  rdoc.rdoc_dir = "docs"
  rdoc.markup = "markdown"
  rdoc.generator = "snapper"
  rdoc.options.push("--copy-files", "misc")
  rdoc.options.push("--copy-files", "LICENSE.txt")
end

RubyLsp::CheckDocs.new(FileList["#{__dir__}/lib/ruby_lsp/**/*.rb"], FileList["#{__dir__}/misc/**/*.gif"])

task default: [:"db:setup", :test]
