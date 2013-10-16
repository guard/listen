module Listen
  module Adapter

    # Polling Adapter that works cross-platform and
    # has no dependencies. This is the adapter that
    # uses the most CPU processing power and has higher
    # file IO than the other implementations.
    #
    class Polling < Base
      DEFAULT_POLLING_LATENCY = 1.0

      def self.usable?
        true
      end

      def start
        Thread.new { _poll_directories }
      end

      private

      def _latency
        listener.options[:latency] || DEFAULT_POLLING_LATENCY
      end

      def _poll_directories
        _napped_loop do
          listener.directories.each do |path|
            _notify_change(path, type: 'Dir', recursive: true)
          end
        end
      end

      def _napped_loop
        loop do
          _nap_time { yield }
        end
      end

      def _nap_time
        start = Time.now.to_f
        yield
        nap_time = _latency - (Time.now.to_f - start)
        sleep(nap_time) if nap_time > 0
      end
    end

  end
end
