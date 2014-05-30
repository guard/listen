module Listen
  module Adapter
    class Base
      include Celluloid

      attr_accessor :listener

      def initialize(listener)
        @listener = listener
      rescue
        _log :error, "adapter config failed: #{$!}:#{$@.join("\n")}"
        raise
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

      def self.usable?
        const_get('OS_REGEXP') =~ RbConfig::CONFIG['target_os']
      end

      private

      def _configure
      end

      def _directories
        listener.directories
      end

      def _notify_change(type, path, options = {})
        unless (worker = listener.async(:change_pool))
          _log :warn, 'Failed to allocate worker from change pool'
          return
        end

        worker.change(type, path, options)
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
