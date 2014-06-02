module Listen
  module Adapter
    # Polling Adapter that works cross-platform and
    # has no dependencies. This is the adapter that
    # uses the most CPU processing power and has higher
    # file IO than the other implementations.
    #
    class Polling < Base
      OS_REGEXP = // # match every OS

      DEFAULTS = { latency: 1.0 }

      private

      def _run
        loop do
          start = Time.now.to_f
          _directories.each do |path|
            _notify_change(:dir, path, recursive: true)
            nap_time = options.latency - (Time.now.to_f - start)
            sleep(nap_time) if nap_time > 0
          end
        end
      end
    end
  end
end
