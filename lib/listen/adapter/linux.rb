module Listen
  module Adapter

    # Listener implementation for Linux `inotify`.
    #
    class Linux < Base
      # Watched inotify events
      #
      # @see http://www.tin.org/bin/man.cgi?section=7&topic=inotify
      # @see https://github.com/nex3/rb-inotify/blob/master/lib/rb-inotify/notifier.rb#L99-L177
      #
      EVENTS = [:recursive, :attrib, :create, :delete, :move, :close_write]

      # The message to show when the limit of inotify watchers is not enough
      #
      INOTIFY_LIMIT_MESSAGE = <<-EOS.gsub(/^\s*/, '')
        Listen error: unable to monitor directories for changes.

        Please head to https://github.com/guard/listen/wiki/Increasing-the-amount-of-inotify-watchers
        for information on how to solve this issue.
      EOS

      def self.usable?
        RbConfig::CONFIG['target_os'] =~ /linux/i
      end

      def initialize(listener)
        require 'rb-inotify'
        super
      end

      def start
        worker = _init_worker
        Thread.new { worker.run }
      rescue Errno::ENOSPC
        abort(INOTIFY_LIMIT_MESSAGE)
      end

      private

      # Initializes a INotify worker and adds a watcher for
      # each directory passed to the adapter.
      #
      # @return [INotify::Notifier] initialized worker
      #
      def _init_worker
        INotify::Notifier.new.tap do |worker|
          _directories_path.each { |path| worker.watch(path, *EVENTS, &_worker_callback) }
        end
      end

      def _worker_callback
        lambda do |event|
          next if _skip_event?(event)

          if _dir_event?(event)
            _notify_change(_event_path(event), type: 'Dir')
          else
            _notify_change(_event_path(event), type: 'File', change: _change(event.flags))
          end
        end
      end

      def _skip_event?(event)
        # Event on root directory
        return true if event.name == ""
        # INotify reports changes to files inside directories as events
        # on the directories themselves too.
        #
        # @see http://linux.die.net/man/7/inotify
        return true if _dir_event?(event) && (event.flags & [:close, :modify]).any?
      end

      def _change(event_flags)
        { modified: [:attrib],
          added:    [:moved_to, :create],
          removed:  [:moved_from, :delete] }.each do |change, flags|
          return change unless (flags & event_flags).empty?
        end
        nil
      end

      def _dir_event?(event)
        event.flags.include?(:isdir)
      end

      def _event_path(event)
        Pathname.new(event.absolute_name)
      end
    end

  end
end
