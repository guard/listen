module Listen
  module Adapters

    # Polling Adapter that works cross-platform and
    # has no dependencies. This is the adapter that
    # uses the most CPU processing power and has higher
    # file IO that the other implementations.
    #
    class Polling < Adapter

      # Start the adapter.
      #
      def start
        super
        @stop = false
        poll
      end

      # Stop the adapter.
      #
      def stop
        super
        @stop = true
      end

    private

      # Poll listener directory for file system changes.
      #
      def poll
        until @stop
          start = Time.now.to_f
          @listener.on_change([@listener.directory], :recursive => true)
          nap_time = @latency - (Time.now.to_f - start)
          sleep(nap_time) if nap_time > 0
        end
      end

    end

  end
end
