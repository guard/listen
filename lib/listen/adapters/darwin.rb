module Listen
  module Adapters

    # Adapter implementation for Mac OS X `FSEvents`.
    #
    class Darwin < Adapter
      extend DependencyManager

      # Declare the adapter's dependencies
      dependency 'rb-fsevent', '~> 0.9'

      LAST_SEPARATOR_REGEX = /\/$/

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
      # @see Listen::Adapter#initialize_worker
      #
      def initialize_worker
        FSEvent.new.tap do |worker|
          worker.watch(directories.dup, :latency => latency) do |changes|
            next if paused

            mutex.synchronize do
              changes.each { |path| @changed_directories << path.sub(LAST_SEPARATOR_REGEX, '') }
            end
          end
        end
      end

      # Starts the worker in a new thread and sleep 0.1 second.
      #
      # @see Listen::Adapter#start_worker
      #
      def start_worker
        @worker_thread = Thread.new { worker.run }
        # The FSEvent worker needs some time to start up. Turnstiles can't
        # be used to wait for it as it runs in a loop.
        # TODO: Find a better way to block until the worker starts.
        sleep 0.1
      end

    end

  end
end
