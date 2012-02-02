module Listen
  module Adapters

    # Adapter implementation for Mac OS X `FSEvents`.
    #
    class Darwin < Adapter
      attr_accessor :latency

      # Initialize the Adapter.
      #
      def initialize(*)
        super
        @worker = FSEvent.new
        @worker.watch(@listener.directory, :latency => 0.1 ) do |changed_dirs|
          changed_dirs.map! { |path| path.sub /\/$/, '' }
          @listener.on_change(changed_dirs)
        end
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
        return false unless RbConfig::CONFIG['target_os'] =~ /darwin1\d/i

        require 'rb-fsevent'
        true
      rescue LoadError
        false
      end

    end

  end
end
