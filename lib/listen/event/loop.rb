require 'thread'

require 'timeout'
require 'listen/event/processor'

module Listen
  module Event
    class Loop
      class Error < RuntimeError
        class ThreadFailedToStart < Error; end
        class AlreadyStarted < Error; end
      end

      def initialize(config)
        @config = config
        @wait_thread = nil
        @mutex = ::Mutex.new
        @state_changed = ::ConditionVariable.new
        @state = :pre_start # ... :starting, :started, :stopped
        @reasons = ::Queue.new
      end

      def wakeup_on_event
        if started? && @wait_thread&.alive?
          _wakeup(:event)
        end
      end

      def started?
        @state == :started
      end

      MAX_STARTUP_SECONDS = 5.0

      def start
       # TODO: use a Fiber instead?
      _transition!(:starting) do
          @state == :pre_start or raise Error::AlreadyStarted
        end

        @wait_thread = Thread.new do
          _process_changes
        end

        Listen::Logger.debug("Waiting for processing to start...")

        _wait_for_state(:started, MAX_STARTUP_SECONDS) or raise Error::ThreadFailedToStart, "thread didn't start in #{MAX_STARTUP_SECONDS} seconds (in state: #{@state.inspect})"

        Listen::Logger.debug('Processing started.')
      end

      def pause
        # TODO: works?
        # fail NotImplementedError
      end

      def teardown
        return if stopped?
        _transition!(:stopped)

        if @wait_thread.alive?
          _wakeup(:teardown)
          @wait_thread.join.kill
        end
        @wait_thread = nil
      end

      def stopped?
        @state == :stopped
      end

      private

      def _transition!(new_state)
        @mutex.synchronize do
          yield if block_given?
          @state = new_state
          @state_changed.signal
        end
      end

      # checks for the given state
      # if not in it, waits for a state change (up to timeout_seconds--`nil` means infinite)
      # returns truthy iff the transition to the desired state has occurred
      def _wait_for_state(state, timeout_seconds = nil)
        @mutex.synchronize do
          if @state != state
            @state_changed.wait(@mutex, timeout_seconds)
          end
          @state == state
        end
      end

      def _process_changes
        processor = Event::Processor.new(@config, @reasons)

        _transition!(:started)

        processor.loop_for(@config.min_delay_between_events)

      rescue StandardError => ex
        _nice_error(ex)
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
