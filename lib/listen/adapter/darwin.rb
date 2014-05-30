module Listen
  module Adapter
    # Adapter implementation for Mac OS X `FSEvents`.
    #
    class Darwin < Base
      OS_REGEXP = /darwin(1.+)?$/i

      # The default delay between checking for changes.
      DEFAULT_LATENCY = 0.1

      private

      def _configure
        require 'rb-fsevent'
        @worker = FSEvent.new
        @worker.watch(_directories.map(&:to_s), latency: _latency) do |changes|
          changes.each do |path|
            new_path = Pathname.new(path.sub(/\/$/, ''))
            _log :debug, "fsevent: #{new_path}"
            _notify_change(:dir, new_path)
          end
        end
      end

      def _run
        @worker.run
      end

      def _latency
        listener.options[:latency] || DEFAULT_LATENCY
      end
    end
  end
end
