require 'thread'

require_relative 'logger'

module Listen
  module Thread
    class << self
      # Creates a new thread with the given name.
      # Any exceptions raised by the thread will be logged with the thread name and complete backtrace.
      def new(name)
        thread_name = "listen-#{name}"

        caller_stack = caller
        ::Thread.new do
          yield
        rescue Exception => ex
          _log_exception(ex, thread_name, caller_stack)
          nil
        end.tap do |thread|
          thread.name = thread_name
        end
      end

      private

      def _log_exception(ex, thread_name, caller_stack)
        complete_backtrace = [*ex.backtrace, "--- Thread.new ---", *caller_stack]
        message = "Exception rescued in #{thread_name}:\n#{_exception_with_causes(ex)}\n#{complete_backtrace * "\n"}"
        Listen::Logger.error(message)
      end

      def _exception_with_causes(ex)
        result = +"#{ex.class}: #{ex}"
        if ex.cause
          result << "\n"
          result << "--- Caused by: ---\n"
          result << _exception_with_causes(ex.cause)
        end
        result
      end
    end
  end
end
