require 'listen/options'

module Listen
  module Adapter
    class Base
      include Celluloid

      attr_reader :options

      # TODO: only used by tests
      DEFAULTS = {}

      def initialize(opts)
        @configured = nil
        options = opts.dup
        @mq = options.delete(:mq)
        @directories = options.delete(:directories)

        Array(@directories).each do |dir|
          next if dir.is_a?(Pathname)
          fail ArgumentError, "not a Pathname: #{dir.inspect}"
        end

        # TODO: actually use this in every adapter
        @recursion = options.delete(:recursion)
        @recursion = true if @recursion.nil?

        defaults = self.class.const_get('DEFAULTS')
        @options = Listen::Options.new(options, defaults)
      rescue
        _log :error, "adapter config failed: #{$!}:#{$@.join("\n")}"
        raise
      end

      # TODO: it's a separate method as a temporary workaround for tests
      def configure
        return if @configured
        @configured = true

        @callbacks ||= {}
        @directories.each do |dir|
          unless dir.is_a?(Pathname)
            fail ArgumentError, "not a Pathname: #{dir.inspect}"
          end

          callback = @callbacks[dir] || lambda do |event|
            _process_event(dir, event)
          end
          @callbacks[dir] = callback
          _configure(dir, &callback)
        end
      end

      def start
        configure
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

      def _queue_change(type, dir, rel_path, options)
        # TODO: temporary workaround to remove dependency on Change through
        # Celluloid in tests
        @mq.send(:_queue_raw_change, type, dir, rel_path, options)
      end

      def _log(*args)
        self.class.send(:_log, *args)
      end

      def self._log(*args)
        Celluloid::Logger.send(*args)
      end
    end
  end
end
