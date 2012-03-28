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
        @workers = Array.new(@directories.size) { |i| init_worker_for(@directories[i]) }
      end

      # Starts the adapter.
      #
      # @param [Boolean] blocking whether or not to block the current thread after starting
      #
      def start(blocking = true)
        super
        @workers_pool = @workers.map { |w| Thread.new { w.run } }
        @poll_thread  = Thread.new { poll_changed_dirs }

        # The FSEvent worker needs sometime to startup. Turnstiles can't
        # be used to wait for it as it runs in a loop.
        # TODO: Find a better way to block until the worker starts.
        sleep @latency
        @poll_thread.join if blocking
      end

      # Stops the adapter.
      #
      def stop
        super
        @workers.map(&:stop)
        @workers_pool.map { |t| Thread.kill(t) if t }
        @poll_thread.join
      end

      # Checks if the adapter is usable on the current OS.
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

      # Initializes a FSEvent worker for a given directory
      # and sets its callback.
      #
      # @param [String] directory the directory to be watched
      #
      # @return [FSEvent] initialized worker
      #
      def init_worker_for(directory)
        FSEvent.new.tap do |worker|
          worker.watch(directory, :latency => @latency) do |directories|
            next if @paused
            @mutex.synchronize do
              directories.each { |path| @changed_dirs << path.sub(LAST_SEPARATOR_REGEX, '') }
            end
          end
        end
      end

    end

  end
end
