module Listen
  module Adapters

    # Watched INotify EVENTS
    #
    # @see http://www.tin.org/bin/man.cgi?section=7&topic=inotify
    # @see https://github.com/nex3/rb-inotify/blob/master/lib/rb-inotify/notifier.rb#L99-L177
    #
    EVENTS = %w[recursive attrib close modify move create delete delete_self move_self]

    # Listener implementation for Linux `inotify`.
    #
    class Linux < Adapter

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
      end

      # Stop the adapter.
      #
      def stop
        super
        @worker.stop
        # Although the worker is stopped, the thread needs to be killed!
        Thread.kill @worker_thread
        @poll_thread.join
      end

      # Check if the adapter is usable on the current OS.
      #
      # @return [Boolean] whether usable or not
      #
      def self.usable?
        return false unless RbConfig::CONFIG['target_os'] =~ /linux/i

        require 'rb-inotify'
        true
      rescue LoadError
        false
      end

    private

      # Initialize INotify worker and set watch callback block.
      #
      def init_worker
        @worker = INotify::Notifier.new
        @worker.watch(@directory, *EVENTS.map(&:to_sym)) do |event|
          if @paused or (
            # Event on root directory
            event.name == ""
          ) or (
            # INotify reports changes to files inside directories as events
            # on the directories themselves too.
            #
            # @see http://linux.die.net/man/7/inotify
            event.flags.include?(:isdir) and event.flags & [:close, :modify] != []
          )
            # Skip all of these!
            next
          end

          @mutex.synchronize do
            @changed_dirs << File.dirname(event.absolute_name)
          end
        end
      end

    end

  end
end
