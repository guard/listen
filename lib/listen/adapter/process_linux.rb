# frozen_string_literal: true

require 'listen'

module Listen
  module Adapter
    class ProcessLinux < Base
      OS_REGEXP = /linux/i
      BIN_PATH = ::File.expand_path("#{__dir__}/../../../bin/inotify_watch")

      def self.forks?
        true
      end

      def _configure(dir, &callback)
      end

      def _run
        dirs_to_watch = @callbacks.keys.map(&:to_s)
        worker = Worker.new(dirs_to_watch, &method(:_process_changes))
        @worker_thread = Thread.new('worker_thread') { worker.run }
      end

      def _process_changes(dirs)
        dirs.each do |dir|
          dir = Pathname.new(dir.sub(%r{/$}, ''))

          @callbacks.each do |watched_dir, callback|
            if watched_dir.eql?(dir) || Listen::Directory.ascendant_of?(watched_dir, dir)
              callback.call(dir)
            end
          end
        end
      end

      def _process_event(dir, path)
        Listen.logger.debug { "inotify: processing path: #{path.inspect}" }
        rel_path = path.relative_path_from(dir).to_s
        _queue_change(:dir, dir, rel_path, recursive: true)
      end

      def _stop
        @worker_thread&.kill
        super
      end

      class Worker
        def initialize(dirs_to_watch, &block)
          @paths = dirs_to_watch
          @callback = block
        end

        def run
          @pipe = IO.popen([BIN_PATH] + @paths)
          @running = true

          while @running && IO.select([@pipe], nil, nil, nil)
            command = @pipe.gets("\0")
            next unless command
            # remove status (M/A/D) and terminator null byte
            dir = command[1..-1].chomp("\0")
            @callback.call([dir])
          end
        rescue Interrupt, IOError, Errno::EBADF
        ensure
          stop
        end

        def stop
          unless @pipe.nil?
            Process.kill('KILL', @pipe.pid) if process_running?(@pipe.pid)
            @pipe.close
          end
        rescue IOError, Errno::EBADF
        ensure
          @running = false
        end

        def process_running?(pid)
          Process.kill(0, pid)
          true
        rescue Errno::ESRCH
          false
        end
      end
    end
  end
end
