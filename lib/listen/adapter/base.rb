module Listen
  module Adapter
    class Base
      include Celluloid

      # The default delay between checking for changes.
      DEFAULT_LATENCY = 0.1

      attr_accessor :listener

      def initialize(listener)
        @listener = listener
      rescue
        _log :error, "adapter config failed: #{$!}:#{$@.join("\n")}"
        raise
      end

      def self.usable?
        const_get('OS_REGEXP') =~ RbConfig::CONFIG['target_os']
      end

      def start
        _configure
        Thread.new do
          begin
            _run
          rescue
            _log :error, "run() in thread failed: #{$!}:#{$@.join("\n")}"
            raise
          end
        end
      end

      def self.local_fs?
        true
      end

      private

      def _configure
      end

      def _latency
        listener.options[:latency] || DEFAULT_LATENCY
      end

      def _directories
        listener.directories
      end

      def _notify_change(type, path, options = {})
        unless listener.listen?
          _log :warn, 'Listener not listening anymore'
          return
        end

        unless (worker = listener.registry[:change_pool])
          _log :error, 'Failed to allocate from change pool'
          return
        end

        worker.async.change(type, path, options)
      rescue RuntimeError
        _log :error, "_notify_change crashed: #{$!}:#{$@.join("\n")}"
        raise
      end

      def _log(type, message)
        Celluloid.logger.send(type, message)
      end
    end
  end
end
