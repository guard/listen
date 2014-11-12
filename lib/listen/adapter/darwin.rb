require 'listen/internals/thread_pool'

module Listen
  module Adapter
    # Adapter implementation for Mac OS X `FSEvents`.
    #
    class Darwin < Base
      OS_REGEXP = /darwin(1.+)?$/i

      # The default delay between checking for changes.
      DEFAULTS = { latency: 0.1 }

      private

      # NOTE: each directory gets a DIFFERENT callback!
      def _configure(dir, &callback)
        require 'rb-fsevent'
        opts = { latency: options.latency }

        @workers ||= Queue.new
        @workers << FSEvent.new.tap do |worker|
          worker.watch(dir.to_s, opts, &callback)
        end
      end

      # NOTE: _run is called within a thread, so run every other
      # worker in it's own thread
      def _run
        first = @workers.pop
        until @workers.empty?
          Listen::Internals::ThreadPool.add do
            begin
              @workers.pop.run
            rescue
              _log_exception 'run() in extra thread(s) failed: %s: %s'
            end
          end
        end
        first.run
      end

      def _process_event(dir, event)
        event.each do |path|
          new_path = Pathname.new(path.sub(/\/$/, ''))
          _log :debug, "fsevent: #{new_path}"
          # TODO: does this preserve symlinks?
          rel_path = new_path.relative_path_from(dir).to_s
          _queue_change(:dir, dir, rel_path, recursive: true)
        end
      end
    end
  end
end
