# typed: false
# frozen_string_literal: true

require_relative "../test_helper"

# Boots the Rails runner server through the full LSP addon activation path —
# exactly like the feature tests do — many times in a row, to reproduce the
# intermittent boot deadlock observed on Ruby 4.0.6 (see PR #726).
#
# Named boot_stress.rb (not *_test.rb) so the normal `rake test` glob skips it.
# Run with: bundle exec ruby -Itest test/stress/boot_stress.rb

$last_progress = Time.now

# If no boot completes for 120 seconds, assume the deadlock happened and dump
# Ruby-level backtraces of every thread. Then leave the process hanging so the
# external shell watchdog can attach gdb/lldb for native backtraces.
Thread.new do
  loop do
    sleep(10)
    next unless Time.now - $last_progress > 120

    $stdout.puts "=== In-process watchdog: no boot progress for 120s; dumping all thread backtraces"
    Thread.list.each do |thread|
      $stdout.puts "--- Thread #{thread.inspect} status=#{thread.status.inspect}"
      $stdout.puts((thread.backtrace || ["<no Ruby backtrace>"]).join("\n"))
    end
    $stdout.puts "=== End of thread dump; leaving the process hung for the external watchdog"
    $stdout.flush
    break
  end
end

module RubyLsp
  module Rails
    class BootStressTest < ActiveSupport::TestCase
      Integer(ENV.fetch("BOOT_STRESS_ITERATIONS", "120")).times do |i|
        test "boot #{format("%03d", i)}" do
          with_server("class User < ApplicationRecord; end", URI("/fake.rb")) do |_server, _uri|
            addon = RubyLsp::Addon.addons.find { |a| a.is_a?(RubyLsp::Rails::Addon) }
            sleep(0.1) while addon.instance_variable_get(:@rails_runner_client).is_a?(NullClient)
            assert_predicate(addon.instance_variable_get(:@rails_runner_client), :connected?)
            $last_progress = Time.now
          end
        end
      end
    end
  end
end
