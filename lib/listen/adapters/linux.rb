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
      def initialize(directories, options = {}, &callback)
        super
        @workers = Array.new(@directories.size) { |i| init_worker_for(@directories[i]) }
      end

      # Start the adapter.
      #
      def start
        super
        @workers_pool = @workers.map { |w| Thread.new { w.run } }
        @poll_thread = Thread.new { poll_changed_dirs }
      end

      # Stop the adapter.
      #
      def stop
        super
        @workers.map(&:stop)
        @workers_pool.map { |t| Thread.kill(t) if t }
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

      # Initializes a INotify worker for a given directory
      # and sets its callback.
      #
      # @param [String] directory the directory to be watched
      #
      # @return [INotify::Notifier] initialized worker
      #
      def init_worker_for(directory)
        worker = INotify::Notifier.new
        worker.watch(directory, *EVENTS.map(&:to_sym)) do |event|
          if @paused || (
            # Event on root directory
            event.name == ""
          ) || (
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
        worker
      end

    end

  end
end
