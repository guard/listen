module Listen
  module Adapters

    # Adapter implementation for Mac OS X `FSEvents`.
    #
    class Darwin < Adapter

      LAST_SEPARATOR_REGEX = /\/$/

      # Initialize the Adapter. See {Listen::Adapter#initialize} for more info.
      #
      def initialize(directory, options = {}, &callback)
        super
        init_worker
      end

      # Start the adapter.
      #
      def start
        super
        @worker_thread = Thread.new { @worker.run }
        @poll_thread   = Thread.new { poll_changed_dirs }

        # The FSEvent worker needs sometime to startup. Turnstiles can't
        # be used to wait for it as it runs in a loop.
        # TODO: Find a better way to block until the worker starts.
        sleep @latency
      end

      # Stop the adapter.
      #
      def stop
        super
        @worker.stop
        Thread.kill @worker_thread
        @poll_thread.join
      end

      # Check if the adapter is usable on the current OS.
      #
      # @return [Boolean] whether usable or not
      #
      def self.usable?
        return false unless RbConfig::CONFIG['target_os'] =~ /darwin(1.+)?$/i

        require 'rb-fsevent'
        true
      rescue LoadError
        false
      end

    private

      # Initialiaze FSEvent worker and set watch callback block
      #
      def init_worker
        @worker = FSEvent.new
        @worker.watch(@directory, :latency => @latency) do |directories|
          next if @paused
          @mutex.synchronize do
            directories.each { |path| @changed_dirs << path.sub(LAST_SEPARATOR_REGEX, '') }
          end
        end
      end

    end

  end
end
