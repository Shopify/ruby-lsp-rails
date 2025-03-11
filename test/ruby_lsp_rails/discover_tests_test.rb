# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  # TODO: convert to a declarative test, using ActiveSupport::TestCase
  class DiscoverTestsTest < Minitest::Test
    include RubyLsp::TestHelper

    def test_handles_minitest_tests_that_extend_active_support_declarative
      source = <<~RUBY
        class MyTest < ActiveSupport::TestCase
          def test_something; end
        end
      RUBY

      with_active_support_declarative_tests(source) do |items|
        assert_equal(1, items.size)
      end
    end

    def with_active_support_declarative_tests(source, &block)
      with_server(source) do |server, uri|
        server.global_state.index.index_single(uri, <<~RUBY)
          module Minitest
            class Test; end
          end

          module ActiveSupport
            module Testing
              module Declarative
              end
            end

            class TestCase < Minitest::Test
              extend Testing::Declarative
            end
          end
        RUBY

        server.process_message(id: 1, method: "rubyLsp/discoverTests", params: {
          textDocument: { uri: uri },
        })

        items = get_response(server)

        yield items
      end
    end

    def get_response(server)
      server.pop_response
      server.pop_response
      result = server.pop_response

      # if result.is_a?(Error)
      #   flunk(result.message)
      # end

      result.response
    end
  end
end
