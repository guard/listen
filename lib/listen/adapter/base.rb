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

      def need_record?
        raise NotImplementedError
      end

      private

      def _latency
        listener.options[:latency] || DEFAULT_LATENCY
      end

      def _notify_change(path, options)
        Actor[:change_pool].async.change(path, options) if listener.listen?
      end
    end

  end
end
