module Listen
  module Adapter
    # @see https://github.com/nex3/rb-inotify
    class Linux < Base
      OS_REGEXP = /linux/i

      DEFAULTS = {
        events: [
          :recursive,
          :attrib,
          :create,
          :delete,
          :move,
          :close_write
        ]
      }

      private

      WIKI_URL = 'https://github.com/guard/listen'\
        '/wiki/Increasing-the-amount-of-inotify-watchers'

      INOTIFY_LIMIT_MESSAGE = <<-EOS.gsub(/^\s*/, '')
        FATAL: Listen error: unable to monitor directories for changes.
        Visit #{WIKI_URL} for info on how to fix this.
      EOS

      def _configure(directory, &callback)
        require 'rb-inotify'
        @worker ||= INotify::Notifier.new
        @worker.watch(directory.to_s, *options.events, &callback)
      rescue Errno::ENOSPC
        # workaround - Celluloid catches abort and prints nothing
        STDERR.puts INOTIFY_LIMIT_MESSAGE
        STDERR.flush
        abort(INOTIFY_LIMIT_MESSAGE)
      end

      def _run
        @worker.run
      end

      def _process_event(directory, event, new_changes)
        # NOTE: avoid using event.absolute_name since new API
        # will need to have a custom recursion implemented
        # to properly match events to configured directories
        path = Pathname.new(event.watcher.path) + event.name

        _log :debug, "inotify: #{event.name} #{path} (#{event.flags.inspect})"

        if /1|true/ =~ ENV['LISTEN_GEM_SIMULATE_FSEVENT']
          if (event.flags & [:moved_to, :moved_from]) || _dir_event?(event)
            new_changes << [:dir, path.dirname]
          else
            new_changes << [:dir, path]
          end
          return
        end

        return if _skip_event?(event)

        cookie_opts = event.cookie.zero? ? {} : { cookie: event.cookie }
        if _dir_event?(event)
          new_changes << [:dir, path, cookie_opts]
          return
        end

        options = { change: _change(event.flags) }
        rel_path = path.relative_path_from(directory)

        # TODO: will be kept separate later
        full_path = directory + rel_path
        new_changes << [:file, full_path, options.merge(cookie_opts)]
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
