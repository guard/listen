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

        event_kinds = [
          StandardWatchEventKinds::ENTRY_CREATE,
          StandardWatchEventKinds::ENTRY_MODIFY,
          StandardWatchEventKinds::ENTRY_DELETE
        ]

        @watcher ||= FileSystems.getDefault.newWatchService
        p @watcher.class.name
        @keys ||= {}
        path = Paths.get(directory.to_s)
        key = path.register(@watcher, *event_kinds)
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
              pathname = Pathname.new(child.to_s).dirname
              _queue_change(:dir, pathname, '.', recursive: true)
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
