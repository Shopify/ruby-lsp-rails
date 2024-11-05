# frozen_string_literal: true

require "bundler/setup"

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)

load "rails/tasks/engine.rake"
load "rails/tasks/statistics.rake"

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"] - ["test/ruby_lsp_rails/server_test.rb"]
end

Rake::TestTask.new("test:server") do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = ["test/ruby_lsp_rails/server_test.rb"]
end

task default: [:"db:setup", :test, "test:server"]
