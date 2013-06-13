module Listen
  module Adapter

    class Base
      include Celluloid

      # The default delay between checking for changes.
      DEFAULT_LATENCY = 0.1

      def self.usable?
        raise NotImplementedError
      end

      def start
        raise NotImplementedError
      end

      private

      def _latency
        _listener.options[:latency] || DEFAULT_LATENCY
      end

      def _directories
        _listener.directories
      end

      def _notify_change(path, options)
        _change_pool.async.change(path, options) if _listener.listen?
      end

      def _listener
        Actor[:listener]
      end

      def _change_pool
        Actor[:change_pool]
      end
    end

  end
end
