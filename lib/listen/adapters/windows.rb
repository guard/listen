require 'set'

module Listen
  module Adapters

    # Adapter implementation for Windows `wdm`.
    #
    class Windows < Adapter

      def self.target_os_regex; /mswin|mingw/i; end
      def self.adapter_gem; 'wdm'; end

      private

      # Initializes a WDM monitor and adds a watcher for
      # each directory passed to the adapter.
      #
      # @return [WDM::Monitor] initialized worker
      #
      # @see Listen::Adapter#initialize_worker
      #
      def initialize_worker
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

      # Start the worker in a new thread and sleep 0.1 second.
      #
      # @see Listen::Adapter#start_worker
      #
      def start_worker
        @worker_thread = Thread.new { worker.run! }
        # Wait for the worker to start. This is needed to avoid a deadlock
        # when stopping immediately after starting.
        sleep 0.1
      end

    end

  end
end
