require 'set'

module Listen
  module Adapters

    # Watched INotify EVENTS
    #
    # @see http://www.tin.org/bin/man.cgi?section=7&topic=inotify
    # @see https://github.com/nex3/rb-inotify/blob/master/lib/rb-inotify/notifier.rb#L99-L177
    #
    EVENTS = %w[recursive attrib close modify move create delete delete_self move_self]

    # Listener implementation for Linux `inotify`.
    #
    class Linux < Adapter

      # Initialize the Adapter. See {Listen::Adapter#initialize} for more info.
      #
      def initialize(directory, options = {}, &callback)
        super
        @changed_dirs = Set.new
        init_worker
      end

      # Start the adapter.
      #
      def start
        super
        Thread.new { @worker.run }
        poll_changed_dirs
      end

      # Stop the adapter.
      #
      def stop
        super
        @worker.stop
      end

      # Check if the adapter is usable on the current OS.
      #
      # @return [Boolean] whether usable or not
      #
      def self.usable?
        return false unless RbConfig::CONFIG['target_os'] =~ /linux/i

        require 'rb-inotify'
        true
      rescue LoadError
        false
      end

    private

      # Initialize INotify worker and set watch callback block.
      #
      def init_worker
        @worker = INotify::Notifier.new
        @worker.watch(@listener.directory, *EVENTS.map(&:to_sym)) do |event|
          unless event.name == "" # Event on root directory
            @changed_dirs << File.dirname(event.absolute_name)
          end
        end
      end

      # Polling around @changed_dirs presence.
      #
      def poll_changed_dirs
        until @stop
          sleep(@latency)

          next if @changed_dirs.empty?
          changed_dirs = @changed_dirs.to_a
          @changed_dirs.clear          
          @callback.call(changed_dirs)
        end
      end

    end

  end
end
