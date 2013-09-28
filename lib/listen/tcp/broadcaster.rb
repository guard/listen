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
        async.run
      end

      # Cleans up sockets and server
      def finalize
        if @server
          @sockets.clear
          @server.close
          @server = nil
        end
      end

      # Broadcasts given payload to all connected recipients
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

      private

      # Continuously accept and handle incoming connections
      def run
        loop {
          async.handle_connection(@server.accept)
        }
      end

      # Handles incoming socket connection
      def handle_connection(socket)
        @sockets << socket
      end

    end

  end
end
