require 'celluloid/io'

module Listen
  module TCP
    class Broadcaster
      include Celluloid::IO

      finalizer :finalize

      attr_reader :server, :sockets

      # Initializes a Celluloid::IO-powered TCP-broadcaster
      #
      # @param [String] host to broadcast on
      # @param [String] port to broadcast on
      #
      # Note: Listens on all addresses when host is nil
      #
      def initialize(host, port)
        @server = TCPServer.new(host, port)
        @sockets = []
      rescue
        _log :error, "Broadcaster.initialize: #{$!.inspect}:#{$@.join("\n")}"
        raise
      end

      # Asynchronously start accepting connections
      def start
        async.run
      end

      # Cleans up sockets and server
      def finalize
        return unless @server

        @sockets.clear
        @server.close
        @server = nil
      end

      # Broadcasts given payload to all connected sockets
      def broadcast(payload)
        @sockets.each do |socket|
          unicast(socket, payload)
        end
      end

      # Unicasts payload to given socket
      #
      # @return [Boolean] whether writing to socket was succesful
      #
      def unicast(socket, payload)
        socket.write(payload)
        true
      rescue IOError, Errno::ECONNRESET, Errno::EPIPE
        @sockets.delete(socket)
        false
      end

      # Continuously accept and handle incoming connections
      def run
        while socket = @server.accept
          handle_connection(socket)
        end
      rescue Celluloid::Task::TerminatedError
        _log :debug, "TCP adapter was terminated: #{$!.inspect}"
      rescue
        _log :error, "Broadcaster.run: #{$!.inspect}:#{$@.join("\n")}"
        raise
      end

      # Handles incoming socket connection
      def handle_connection(socket)
        @sockets << socket
      end

      def _log(type, message)
        Celluloid.logger.send(type, message)
      end
    end
  end
end
