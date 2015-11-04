require 'thread'
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

        @workers ||= ::Queue.new
        @workers << FSEvent.new.tap do |worker|
          _log :debug, "fsevent: watching: #{dir.to_s.inspect}"
          worker.watch(dir.to_s, opts, &callback)
        end
      end

      def _run
        first = @workers.pop

        # NOTE: _run is called within a thread, so run every other
        # worker in it's own thread
        _run_workers_in_background(_to_array(@workers))
        _run_worker(first)
      end

      def _process_event(dir, event)
        _log :debug, "fsevent: processing event: #{event.inspect}"
        event.each do |path|
          new_path = Pathname.new(path.sub(/\/$/, ''))
          _log :debug, "fsevent: #{new_path}"
          # TODO: does this preserve symlinks?
          rel_path = new_path.relative_path_from(dir).to_s
          _queue_change(:dir, dir, rel_path, recursive: true)
        end
      end

      def _run_worker(worker)
        _log :debug, "fsevent: running worker: #{worker.inspect}"
        worker.run
      rescue
        _log_exception 'fsevent: running worker failed: %s: %s'
      end

      def _run_workers_in_background(workers)
        workers.each do |worker|
          # NOTE: while passing local variables to the block below is not
          # thread safe, using 'worker' from the enumerator above is ok
          Listen::Internals::ThreadPool.add { _run_worker(worker) }
        end
      end

      def _to_array(queue)
        workers = []
        workers << queue.pop until queue.empty?
        workers
      end
    end
  end
end
