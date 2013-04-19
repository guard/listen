module Listen
  module Adapters

    # Adapter implementation for Mac OS X `FSEvents`.
    #
    class Darwin < Adapter
      extend DependencyManager

      # Declare the adapter's dependencies
      dependency 'rb-fsevent', '~> 0.9'

      LAST_SEPARATOR_REGEX = /\/$/

      attr_accessor :worker, :worker_thread, :poll_thread

      # Initializes the Adapter.
      #
      # @see Listen::Adapter#initialize
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
        super

        @worker_thread = Thread.new { worker.run }

        # The FSEvent worker needs some time to start up. Turnstiles can't
        # be used to wait for it as it runs in a loop.
        # TODO: Find a better way to block until the worker starts.
        sleep 0.1

        @poll_thread = Thread.new { poll_changed_directories } if report_changes?

        worker_thread.join if blocking
      end

      # Stops the adapter.
      #
      def stop
        mutex.synchronize do
          return if stopped
          super
        end

        worker.stop
        Thread.kill(worker_thread) if worker_thread
        poll_thread.join if poll_thread
      end

      # Checks if the adapter is usable on Mac OSX.
      #
      # @return [Boolean] whether usable or not
      #
      def self.usable?
        return false if RbConfig::CONFIG['target_os'] !~ /darwin(1.+)?$/i
        super
      end

      private

      # Initializes a FSEvent worker and adds a watcher for
      # each directory passed to the adapter.
      #
      # @return [FSEvent] initialized worker
      #
      def init_worker
        FSEvent.new.tap do |worker|
          worker.watch(directories.dup, :latency => latency) do |changes|
            next if paused

            mutex.synchronize do
              changes.each { |path| @changed_directories << path.sub(LAST_SEPARATOR_REGEX, '') }
            end
          end
        end
      end

    end

  end
end
