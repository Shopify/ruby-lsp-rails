# typed: strict
# frozen_string_literal: true

# Add your extra requires here (`bin/tapioca require` can be used to bootstrap this list)

require "rails/all"
require "ruby_lsp/internal"
require "ruby_lsp/addon/process_server"
require "ruby_lsp/addon/process_client"
require "ruby_lsp/test_helper"
require "minitest/unit"
require "mocha/minitest"
require "spoom/backtrace_filter/minitest"
require "webmock/minitest"
