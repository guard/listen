module Listen
  module Adapters

    # Listener implementation for Linux `inotify`.
    #
    class Linux < Adapter

      # Watched inotify events
      #
      # @see http://www.tin.org/bin/man.cgi?section=7&topic=inotify
      # @see https://github.com/nex3/rb-inotify/blob/master/lib/rb-inotify/notifier.rb#L99-L177
      #
      EVENTS = %w[recursive attrib close modify move create delete delete_self move_self]

      # The message to show when the limit of inotify watchers is not enough
      #
      INOTIFY_LIMIT_MESSAGE = <<-EOS.gsub(/^\s*/, '')
        Listen error: unable to monitor directories for changes.

        Please head to https://github.com/guard/listen/wiki/Increasing-the-amount-of-inotify-watchers
        for information on how to solve this issue.
      EOS

      # Initializes the Adapter. See {Listen::Adapter#initialize} for more info.
      #
      def initialize(directories, options = {}, &callback)
        super
        @worker = init_worker
      rescue Errno::ENOSPC
        abort(INOTIFY_LIMIT_MESSAGE)
      end

      # Starts the adapter.
      #
      # @param [Boolean] blocking whether or not to block the current thread after starting
      #
      def start(blocking = true)
        @mutex.synchronize do
          return if @stop == false
          super
        end

        @worker_thread = Thread.new { @worker.run }
        @poll_thread   = Thread.new { poll_changed_dirs }
        @poll_thread.join if blocking
      end

      # Stops the adapter.
      #
      def stop
        @mutex.synchronize do
          return if @stop == true
          super
        end

        @worker.stop
        Thread.kill(@worker_thread) if @worker_thread
        @poll_thread.join
      end

      # Check if the adapter is usable on the current OS.
      #
      # @return [Boolean] whether usable or not
      #
      def self.usable?
        return false unless /linux/i.match(RbConfig::CONFIG['target_os'])

        require 'rb-inotify'
        true
      rescue LoadError
        false
      end

    private

      # Initializes a INotify worker and adds a watcher for
      # each directory passed to the adapter.
      #
      # @return [INotify::Notifier] initialized worker
      #
      def init_worker
        worker = INotify::Notifier.new
        @directories.each do |directory|
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
        end
        worker
      end

    end

  end
end
