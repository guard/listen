require 'celluloid/io'

module Listen
  module TCP
    class Broadcaster
      include Celluloid::IO

      finalizer :finalize

      # Initializes a Celluloid::IO-powered TCP-broadcaster
      #
      # @param [String] host to broadcast on
      # @param [String] port to broadcast on
      #
      # Note: Listens on all addresses when host is nil
      #
      def initialize(host, port)
        @sockets = []
        _log :debug, format('Broadcaster: tcp server listening on: %s:%s',
                            host, port)
        @server = TCPServer.new(host, port)
      rescue
        _log :error, format('Broadcaster.initialize: %s:%s', $ERROR_INFO,
                            $ERROR_POSITION * "\n")
        raise
      end

      # Asynchronously start accepting connections
      def start
        async.run
      end

      # Cleans up sockets and server
      def finalize
        @sockets.map(&:close) if @sockets
        @sockets = nil

        return unless @server
        @server.close
        @server = nil
      end

      # Broadcasts given payload to all connected sockets
      def broadcast(payload)
        active_sockets = @sockets.select do |socket|
          _unicast(socket, payload)
        end
        @sockets.replace(active_sockets)
      end

      # Continuously accept and handle incoming connections
      def run
        while (socket = @server.accept)
          @sockets << socket
        end
      rescue Celluloid::Task::TerminatedError
        _log :debug, "TCP adapter was terminated: #{$ERROR_INFO}"
      rescue
        _log :error, format('Broadcaster.run: %s:%s', $ERROR_INFO,
                            $ERROR_POSITION * "\n")
        raise
      end

      private

      def _log(type, message)
        Celluloid::Logger.send(type, message)
      end

      def _unicast(socket, payload)
        socket.write(payload)
        true
      rescue IOError, Errno::ECONNRESET, Errno::EPIPE
        _log :debug, "Broadcaster failed: #{socket.inspect}"
        false
      end
    end
  end
end
