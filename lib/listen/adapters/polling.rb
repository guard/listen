module Listen
  module Adapters

    # The default delay between checking for changes.
    DEFAULT_POLLING_LATENCY = 1.0

    # Polling Adapter that works cross-platform and
    # has no dependencies. This is the adapter that
    # uses the most CPU processing power and has higher
    # file IO than the other implementations.
    #
    class Polling < Adapter
      extend DependencyManager

      attr_accessor :worker, :poll_thread

      # Initialize the Adapter.
      #
      # @see Listen::Adapter#initialize
      #
      def initialize(directories, options = {}, &callback)
        @latency ||= DEFAULT_POLLING_LATENCY
        super
      end

      # Start the adapter.
      #
      # @param [Boolean] blocking whether or not to block the current thread after starting
      #
      def start(blocking = true)
        super
        @poll_thread = Thread.new { poll }
        poll_thread.join if blocking
      end

      # Stop the adapter.
      #
      def stop
        mutex.synchronize do
          return if stopped
          super
        end

        poll_thread.join
      end

    private

      # Poll listener directory for file system changes.
      #
      def poll
        until stopped
          next if paused

          start = Time.now.to_f
          callback.call(directories.dup, :recursive => true)
          turnstile.signal
          nap_time = latency - (Time.now.to_f - start)
          sleep(nap_time) if nap_time > 0
        end
      rescue Interrupt
      end

    end

  end
end
