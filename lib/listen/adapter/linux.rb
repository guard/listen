module Listen
  module Adapter
    # Listener implementation for Linux `inotify`.
    # @see https://github.com/nex3/rb-inotify
    #
    class Linux < Base
      OS_REGEXP = /linux/i

      EVENTS = [:recursive, :attrib, :create, :delete, :move, :close_write]

      WIKI_URL = 'https://github.com/guard/listen'\
        '/wiki/Increasing-the-amount-of-inotify-watchers'

      INOTIFY_LIMIT_MESSAGE = <<-EOS.gsub(/^\s*/, '')
        FATAL: Listen error: unable to monitor directories for changes.

        Please head to #{WIKI_URL}
        for information on how to solve this issue.
      EOS

      private

      def _configure
        require 'rb-inotify'
        @worker = INotify::Notifier.new
        _directories.each do |path|
          @worker.watch(path.to_s, *EVENTS, &_callback)
        end
      rescue Errno::ENOSPC
        # workaround - Celluloid catches abort and prints nothing
        STDERR.puts INOTIFY_LIMIT_MESSAGE
        STDERR.flush
        abort(INOTIFY_LIMIT_MESSAGE)
      end

      def _run
        @worker.run
      end

      def _callback
        lambda do |event|
          # NOTE: avoid using event.absolute_name since new API
          # will need to have a custom recursion implemented
          # to properly match events to configured directories
          path = Pathname.new(event.watcher.path) + event.name

          _log :debug, "inotify: #{event.name} #{path} (#{event.flags.inspect})"

          if /1|true/ =~ ENV['LISTEN_GEM_SIMULATE_FSEVENT']
            if (event.flags & [:moved_to, :moved_from]) || _dir_event?(event)
              _notify_change(:dir, path.dirname)
            else
              _notify_change(:dir, path)
            end
          else
            next if _skip_event?(event)
            cookie_opts = event.cookie.zero? ? {} : { cookie: event.cookie }
            if _dir_event?(event)
              _notify_change(:dir, path, cookie_opts)
            else
              options = { change: _change(event.flags) }
              _notify_change(:file, path, options.merge(cookie_opts))
            end
          end
        end
      end

      def _skip_event?(event)
        # Event on root directory
        return true if event.name == ''
        # INotify reports changes to files inside directories as events
        # on the directories themselves too.
        #
        # @see http://linux.die.net/man/7/inotify
        _dir_event?(event) && (event.flags & [:close, :modify]).any?
      end

      def _change(event_flags)
        { modified:   [:attrib, :close_write],
          moved_to:   [:moved_to],
          moved_from: [:moved_from],
          added:      [:create],
          removed:    [:delete] }.each do |change, flags|
          return change unless (flags & event_flags).empty?
        end
        nil
      end

      def _dir_event?(event)
        event.flags.include?(:isdir)
      end
    end
  end
end
