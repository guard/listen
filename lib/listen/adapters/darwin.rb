module Listen
  module Adapters

    # Adapter implementation for Mac OS X `FSEvents`.
    #
    class Darwin < Adapter

      LAST_SEPARATOR_REGEX = /\/$/

      # Initializes the Adapter. See {Listen::Adapter#initialize} for more info.
      #
      def initialize(directories, options = {}, &callback)
        super
        @worker = init_worker
      end

      # Starts the adapter.
      #
      # @param [Boolean] blocking whether or not to block the current thread after starting
      #
      def start(blocking = true)
        @mutex.synchronize do
          return if @stop == false
          super
        end

        @worker_thread = Thread.new { @worker.run }
        @poll_thread   = Thread.new { poll_changed_dirs }

        # The FSEvent worker needs sometime to startup. Turnstiles can't
        # be used to wait for it as it runs in a loop.
        # TODO: Find a better way to block until the worker starts.
        sleep @latency
        @poll_thread.join if blocking
      end

      # Stops the adapter.
      #
      def stop
        @mutex.synchronize do
          return if @stop == true
          super
        end

        @worker.stop
        Thread.kill(@worker_thread) if @worker_thread
        @poll_thread.join
      end

      # Checks if the adapter is usable on the current OS.
      #
      # @return [Boolean] whether usable or not
      #
      def self.usable?
        return false unless /darwin(1.+)?$/i.match(RbConfig::CONFIG['target_os'])

        require 'rb-fsevent'
        true
      rescue LoadError
        false
      end

      private

      # Initializes a FSEvent worker and adds a watcher for
      # each directory passed to the adapter.
      #
      # @return [FSEvent] initialized worker
      #
      def init_worker
        FSEvent.new.tap do |worker|
          worker.watch(@directories.dup, :latency => @latency) do |changes|
            next if @paused
            @mutex.synchronize do
              changes.each { |path| @changed_dirs << path.sub(LAST_SEPARATOR_REGEX, '') }
            end
          end
        end
      end

    end

  end
end
