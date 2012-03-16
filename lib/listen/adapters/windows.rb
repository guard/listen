require 'set'

module Listen
  module Adapters

    # Adapter implementation for Windows `fchange`.
    #
    class Windows < Adapter

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
        @poll_thread   = Thread.new { poll_changed_dirs(true) }
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
        return false unless RbConfig::CONFIG['target_os'] =~ /mswin|mingw/i

        require 'rb-fchange'
        true
      rescue LoadError
        false
      end

    private

      # Initialiaze FSEvent worker and set watch callback block
      #
      def init_worker
        @worker = FChange::Notifier.new
        @worker.watch(@directory, :all_events, :recursive) do |event|
          next if @paused
          @mutex.synchronize do
            @changed_dirs << File.expand_path(event.watcher.path)
          end
        end
      end

    end

  end
end
