module Listen
  module Adapter

    # Adapter implementation for Mac OS X `FSEvents`.
    #
    class Darwin < Base

      def self.usable?
        RbConfig::CONFIG['target_os'] =~ /darwin(1.+)?$/i
      end

      def initialize(listener)
        require 'rb-fsevent'
        super
      end

      def start
        worker = _init_worker
        Thread.new { worker.run }
      end

      private

      # Initializes a FSEvent worker and adds a watcher for
      # each directory listened.
      #
      def _init_worker
        FSEvent.new.tap do |worker|
          worker.watch(_directories_path, latency: _latency) do |changes|
            _changes_path(changes).each { |path| _notify_change(path, type: 'Dir') }
          end
        end
      end

      def _changes_path(changes)
        changes.map do |path|
          path.sub!(/\/$/, '')
          Pathname.new(path)
        end
      end
    end

  end
end
