module Listen
  module Adapter
    # Adapter implementation for Mac OS X `FSEvents`.
    #
    class Darwin < Base
      OS_REGEXP = /darwin(1.+)?$/i

      # The default delay between checking for changes.
      DEFAULTS = { latency: 0.1 }

      private

      def _configure
        require 'rb-fsevent'
        @worker ||= FSEvent.new
        opts = { latency: options.latency }
        @worker.watch(_directories.map(&:to_s), opts) do |changes|
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
    end
  end
end
