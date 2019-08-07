module Listen
  module Adapter
    # @see https://docs.oracle.com/javase/tutorial/essential/io/notification.html
    class Jruby < Base
      def self.usable?
        RUBY_ENGINE == 'jruby'
      end

      private

      def _configure(directory, &_callback)
        require 'java'
        java_import 'java.nio.file.FileSystems'
        java_import 'java.nio.file.Paths'
        java_import 'java.nio.file.StandardWatchEventKinds'

        @event_kind_map ||= {
          StandardWatchEventKinds::ENTRY_CREATE => :added,
          StandardWatchEventKinds::ENTRY_MODIFY => :modified,
          StandardWatchEventKinds::ENTRY_DELETE => :removed
        }

        @watcher ||= FileSystems.getDefault.newWatchService
        p @watcher.class.name
        @keys ||= {}
        path = Paths.get(directory.to_s)
        key = path.register(@watcher, *@event_kind_map.keys)
        @keys[key] = path
      end

      def _run
        loop do
          key = @watcher.take
          dir = @keys[key]
          unless dir.nil?
            key.pollEvents.each do |event|
              kind = event.kind
              next if kind == StandardWatchEventKinds::OVERFLOW
              name = event.context
              child = dir.resolve(name)
              dirname = Pathname.new(child.to_s).dirname
              full_path = Pathname.new(child.to_s)
              if full_path.directory?
                p [:dir, dirname]
                _queue_change(:dir, dirname, '.', recursive: true)
              elsif full_path.exist?
                path = full_path.relative_path_from(dirname)
                changed = @event_kind_map[kind]
                p [:file, dirname, path.to_s, changed: changed]
                _queue_change(:file, dirname, path.to_s, changed: changed)
              end
            end
          end
          valid = key.reset
          unless valid
            @keys.delete(key)
            break if @keys.empty?
          end
        end
      end

      def _process_event(dir, event); end
    end
  end
end
