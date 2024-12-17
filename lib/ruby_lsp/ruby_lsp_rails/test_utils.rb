# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    module TestUtils
      extend T::Sig

      sig { params(server: RubyLsp::Server).returns(RubyLsp::Result) }
      def pop_result(server)
        result = server.pop_response
        result = server.pop_response until result.is_a?(RubyLsp::Result) || result.is_a?(RubyLsp::Error)

        refute_instance_of(
          RubyLsp::Error,
          result,
          -> { "Failed to execute request #{T.cast(result, RubyLsp::Error).message}" },
        )
        T.cast(result, RubyLsp::Result)
      end

      def pop_log_notification(message_queue, type)
        log = message_queue.pop
        return log if log.params.type == type

        log = message_queue.pop until log.params.type == type
        log
      end

      def pop_message(outgoing_queue, &block)
        message = outgoing_queue.pop
        return message if block.call(message)

        message = outgoing_queue.pop until block.call(message)
        message
      end
    end
  end
end
