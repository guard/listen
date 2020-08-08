require 'thread'

require 'timeout'
require 'listen/event/processor'

module Listen
  module Event
    class Loop
      class Error < RuntimeError
        class NotStarted < Error
        end
      end

      def initialize(config)
        @config = config
        @wait_thread = nil
        @state = :pre_start # ... :starting, :started, :stopped
        @reasons = ::Queue.new
      end

      def wakeup_on_event
        if started? && @wait_thread.alive?
          _wakeup(:event)
        end
      end

      def started?
        @state == :started
      end

      def start
        # TODO: use a Fiber instead?
        @state = :starting
        q = ::Queue.new
        @wait_thread = Thread.new do
          _wait_for_changes(q)
        end

        Listen::Logger.debug('Waiting for processing to start...')
        Timeout.timeout(5) { q.pop }
      end

      def resume
        fail Error::NotStarted if @state == :pre_start
        return unless @wait_thread
        _wakeup(:resume)
      end

      def pause
        # TODO: works?
        # fail NotImplementedError
      end

      def teardown
        return if stopped?
        if @wait_thread.alive?
          _wakeup(:teardown)
          @wait_thread.join.kill
        end
        @wait_thread = nil
        @state = :stopped
      end

      def stopped?
        @state == :stopped
      end

      private

      def _wait_for_changes(ready_queue)
        processor = Event::Processor.new(@config, @reasons)

        _wait_until_resumed(ready_queue)
        processor.loop_for(@config.min_delay_between_events)
      rescue StandardError => ex
        _nice_error(ex)
      end

      def _sleep(*args)
        Kernel.sleep(*args)
      end

      def _wait_until_resumed(ready_queue)
        ready_queue << :ready
        sleep
        @state = :started
      end

      def _nice_error(ex)
        indent = "\n -- "
        msg = format(
          'exception while processing events: %s Backtrace:%s%s',
          ex,
          indent,
          ex.backtrace * indent
        )
        Listen::Logger.error(msg)
      end

      def _wakeup(reason)
        @reasons << reason
        @wait_thread.wakeup
      end
    end
  end
end
