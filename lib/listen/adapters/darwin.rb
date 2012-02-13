module Listen
  module Adapters

    # Adapter implementation for Mac OS X `FSEvents`.
    #
    class Darwin < Adapter

      # Initialize the Adapter.
      #
      def initialize(*)
        super
        init_worker
      end

      # Start the adapter.
      #
      def start
        super
        @worker.run
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
        return false unless RbConfig::CONFIG['target_os'] =~ /darwin(1.+)?$/i

        require 'rb-fsevent'
        true
      rescue LoadError
        false
      end

    private

      # Initialiaze FSEvent worker and set watch callback block
      #
      def init_worker
        @worker = FSEvent.new
        @worker.watch(@listener.directory, :latency => @latency) do |changed_dirs|
          changed_dirs.map! { |path| path.sub /\/$/, '' }
          @listener.on_change(changed_dirs)
        end
      end

    end

  end
end
