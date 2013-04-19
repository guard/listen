require 'set'

module Listen
  module Adapters

    # Adapter implementation for Windows `wdm`.
    #
    class Windows < Adapter
      attr_accessor :worker, :worker_thread, :poll_thread

      def self.target_os_regex; /mswin|mingw/i; end
      def self.adapter_gem; 'wdm'; end

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
        @worker_thread = Thread.new { worker.run! }

        # Wait for the worker to start. This is needed to avoid a deadlock
        # when stopping immediately after starting.
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

    private

      # Initializes a WDM monitor and adds a watcher for
      # each directory passed to the adapter.
      #
      # @return [WDM::Monitor] initialized worker
      #
      def init_worker
        callback = Proc.new do |change|
          next if paused

          mutex.synchronize do
            @changed_directories << File.dirname(change.path)
          end
        end

        WDM::Monitor.new.tap do |worker|
          directories.each { |dir| worker.watch_recursively(dir, &callback) }
        end
      end

    end

  end
end
