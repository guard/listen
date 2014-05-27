module Listen
  module Adapter
    # Adapter implementation for Mac OS X `FSEvents`.
    #
    class Darwin < Base
      OS_REGEXP = /darwin(1.+)?$/i

      private

      def _configure
        require 'rb-fsevent'
        @worker = FSEvent.new
        @worker.watch(_directories.map(&:to_s), latency: _latency) do |changes|
          changes.each do |path|
            new_path = Pathname.new(path.sub(/\/$/, ''))
            _notify_change(:dir, new_path)
          end
        end
      end

      def _run
        @worker.run
      end
    end
  end
end
