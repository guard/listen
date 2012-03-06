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
        @changed_dirs = Set.new
        init_worker
      end

      # Start the adapter.
      #
      def start
        super
        Thread.new { @worker.run }
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
        @worker.watch(@directory, :all_events, :recursive) do |event|
          next if @paused
          
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
          @callback.call(changed_dirs, :recursive => true)
        end
      end

    end

  end
end
