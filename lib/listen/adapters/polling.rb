module Listen
  module Adapters

    # The default delay between checking for changes.
    DEFAULT_POLLING_LATENCY = 1.0

    # Polling Adapter that works cross-platform and
    # has no dependencies. This is the adapter that
    # uses the most CPU processing power and has higher
    # file IO that the other implementations.
    #
    class Polling < Adapter

      # Initialize the Adapter. See {Listen::Adapter#initialize} for more info.
      #
      def initialize(directory, options = {}, &callback)
        @latency ||= DEFAULT_POLLING_LATENCY
        super
      end

      # Start the adapter.
      #
      def start
        super
        poll
      end

      # Stop the adapter.
      #
      def stop
        super
      end

    private

      # Poll listener directory for file system changes.
      #
      def poll
        until @stop
          sleep(0.1) && next if @paused

          start = Time.now.to_f
          @callback.call([@directory], :recursive => true)
          nap_time = @latency - (Time.now.to_f - start)
          sleep(nap_time) if nap_time > 0
        end
      rescue Interrupt
      end

    end

  end
end
