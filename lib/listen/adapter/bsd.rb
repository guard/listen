module Listen
  module Adapter

    # Listener implementation for BSD's `kqueue`.
    #
    class BSD < Base
      # Watched kqueue events
      #
      # @see http://www.freebsd.org/cgi/man.cgi?query=kqueue
      # @see https://github.com/mat813/rb-kqueue/blob/master/lib/rb-kqueue/queue.rb
      #
      EVENTS = [:delete, :write, :extend, :attrib, :rename] # :link, :revoke

      # The message to show when wdm gem isn't available
      #
      BUNDLER_DECLARE_GEM = <<-EOS.gsub(/^ {6}/, '')
        Please add the following to your Gemfile to avoid polling for changes:
          require 'rbconfig'
          gem 'rb-kqueue', '>= 0.2' if RbConfig::CONFIG['target_os'] =~ /freebsd/i
      EOS

      def self.usable?
        if RbConfig::CONFIG['target_os'] =~ /freebsd/i
          require 'rb-kqueue'
          require 'find'
          true
        end
      rescue LoadError
        Kernel.warn BUNDLER_DECLARE_GEM
        false
      end

      def start
        worker = _init_worker
        Thread.new { worker.poll }
      end

      private

      # Initializes a kqueue Queue and adds a watcher for each files in
      # the directories passed to the adapter.
      #
      # @return [INotify::Notifier] initialized kqueue
      #
      def _init_worker
        KQueue::Queue.new.tap do |queue|
          _directories_path.each do |path|
            Find.find(path) { |file_path| _watch_file(file_path, queue) }
          end
        end
      end

      def _worker_callback
        lambda do |event|
           _notify_change(_event_path(event), type: 'File', change: _change(event.flags))

            # If it is a directory, and it has a write flag, it means a
            # file has been added so find out which and deal with it.
            # No need to check for removed files, kqueue will forget them
            # when the vfs does.
           _watch_for_new_file(event) if _new_file_added?(event)
        end
      end

      def _change(event_flags)
        { modified: [:attrib, :extend],
          added:    [:write],
          removed:  [:rename, :delete] }.each do |change, flags|
          return change unless (flags & event_flags).empty?
        end
        nil
      end

      def _event_path(event)
        Pathname.new(event.watcher.path)
      end

      def _new_file_added?(event)
        File.directory?(event.watcher.path) && event.flags.include?(:write)
      end

      def _watch_for_new_file(event)
        queue = event.watcher.queue
        Find.find(path) do |file_path|
          _watch_file(file_path, queue) unless queue.watchers.detect { |k,v| v.path == file.to_s }
        end
      end

      def _watch_file(path, queue)
        queue.watch_file(path, *EVENTS, &_worker_callback)
      end
    end

  end
end
