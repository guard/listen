require 'listen/options'

module Listen
  module Adapter
    class Base
      include Celluloid

      attr_reader :options

      # TODO: only used by tests
      DEFAULTS = {}

      def initialize(opts)
        options = opts.dup
        @mq = options.delete(:mq)
        @directories = options.delete(:directories)

        # TODO: actually use this in every adapter
        @recursion = options.delete(:recursion)
        @recursion = true if @recursion.nil?

        defaults = self.class.const_get('DEFAULTS')
        @options = Listen::Options.new(options, defaults)
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
        @directories
      end

      def _notify_change(type, path, options = {})
        unless (worker = @mq.async(:change_pool))
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
