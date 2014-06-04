# Listener implementation for BSD's `kqueue`.
# @see http://www.freebsd.org/cgi/man.cgi?query=kqueue
# @see https://github.com/mat813/rb-kqueue/blob/master/lib/rb-kqueue/queue.rb
#
module Listen
  module Adapter
    class BSD < Base
      OS_REGEXP = /bsd|dragonfly/i

      DEFAULTS = {
        events: [
          :delete,
          :write,
          :extend,
          :attrib,
          :rename
          # :link, :revoke
        ]
      }

      BUNDLER_DECLARE_GEM = <<-EOS.gsub(/^ {6}/, '')
        Please add the following to your Gemfile to avoid polling for changes:
          require 'rbconfig'
          if RbConfig::CONFIG['target_os'] =~ #{OS_REGEXP}
            gem 'rb-kqueue', '>= 0.2'

            # Base versions have known conflicts/bugs
            # Even master branches may not work...
            gem 'ffi', github: 'carpetsmoker/ffi', ref: 'ac63e07f7'
            gem 'celluloid', github: 'celluloid/celluloid', ref: '7fdef04'
          end
      EOS

      BSD_EXPERIMENTAL = <<-EOS.gsub(/^ {6}/, '')
        NOTE *BSD SUPPORT IS EXPERIMENTAL!

        In fact, it likely WONT WORK!!!!

        (see: https://github.com/guard/listen/issues/220)

        If you're brave enough, feel free to suggest pull requests and
        experiment on your own. For help, browse existing issues marked 'bsd'
        for clues, tips and workaround.
      EOS

      def self.usable?
        return false unless super
        Kernel.warn BSD_EXPERIMENTAL
        require 'rb-kqueue'
        require 'find'
        true
      rescue LoadError
        Kernel.warn BUNDLER_DECLARE_GEM
        false
      end

      private

      def _configure(directory, &_callback)
        @worker ||= KQueue::Queue.new
        # use Record to make a snapshot of dir, so we
        # can detect new files
        _find(directory.to_s) { |path| _watch_file(path, @worker) }
      end

      def _run
        @worker.run
      end

      def _process_event(dir, event)
        full_path = _event_path(event)
        if full_path.directory?
          # Force dir content tracking to kick in, or we won't have
          # names of added files
          _queue_change(:dir, dir, '.', recursive: true)
        else
          path = full_path.relative_path_from(dir)
          _queue_change(:file, dir, path, change: _change(event.flags))
        end

        # If it is a directory, and it has a write flag, it means a
        # file has been added so find out which and deal with it.
        # No need to check for removed files, kqueue will forget them
        # when the vfs does.
        _watch_for_new_file(event) if path.directory?
      end

      def _change(event_flags)
        { modified: [:attrib, :extend],
          added:    [:write],
          removed:  [:rename, :delete]
        }.each do |change, flags|
          return change unless (flags & event_flags).empty?
        end
        nil
      end

      def _event_path(event)
        Pathname.new(event.watcher.path)
      end

      def _watch_for_new_file(event)
        queue = event.watcher.queue
        _find(_event_path(event).to_s) do |file_path|
          unless queue.watchers.detect { |_, v| v.path == file_path.to_s }
            _watch_file(file_path, queue)
          end
        end
      end

      def _watch_file(path, queue)
        queue.watch_file(path, *options.events, &_worker_callback)
      end

      # Quick rubocop workaround
      def _find(*paths)
        Find.send(:find, *paths)
      end
    end
  end
end
