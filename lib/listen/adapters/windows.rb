require 'set'

module Listen
  module Adapters

    # Adapter implementation for Windows `fchange`.
    #
    class Windows < Adapter

      # Initialize the Adapter.
      #
      def initialize(*)
        super
        @latency ||= 0.1
        @changed_dirs = Set.new
        init_worker
      end

      # Start the adapter.
      #
      def start
        super
        Thread.new { @worker.run }
        @stop = false
        poll_changed_dirs
      end

      # Stop the adapter.
      #
      def stop
        super
        @worker.stop
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
        @worker.watch(@listener.directory, :all_events, :recursive) do |event|
          @changed_dirs << File.expand_path(event.watcher.path)
        end
      end
      
      # Polling around @changed_dirs presence.
      #
      def poll_changed_dirs
        until @stop
          sleep(@latency)
          
          next if @changed_dirs.empty?
          changed_dirs = @changed_dirs.to_a
          @changed_dirs.clear          
          @listener.on_change(changed_dirs, :recursive => true)
        end
      end

    end

  end
end
