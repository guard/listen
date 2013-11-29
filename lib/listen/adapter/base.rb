module Listen
  module Adapter

    class Base
      include Celluloid

      # The default delay between checking for changes.
      DEFAULT_LATENCY = 0.1

      attr_accessor :listener

      def initialize(listener)
        @listener = listener
      end

      def self.usable?
        raise NotImplementedError
      end

      def start
        raise NotImplementedError
      end

      private

      def _latency
        listener.options[:latency] || DEFAULT_LATENCY
      end

      def _directories_path
        listener.directories.map(&:to_s)
      end

      def _notify_change(path, options)
        sleep 0.01 until listener.registry[:change_pool]
        listener.registry[:change_pool].async.change(path, options) if listener.listen?
      end
    end

  end
end
