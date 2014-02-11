require 'celluloid/io'

module Listen
  module Adapter

    # Adapter to receive file system modifications over TCP
    class TCP < Base
      include Celluloid::IO

      finalizer :finalize

      attr_reader :buffer, :socket

      def self.usable?
        true
      end

      # Initializes and starts a Celluloid::IO-powered TCP-recipient
      def start
        @socket = TCPSocket.new(listener.host, listener.port)
        @buffer = String.new
        run
      end

      # Cleans up buffer and socket
      def finalize
        @buffer = nil
        if @socket
          @socket.close
          @socket = nil
        end
      end

      # Number of bytes to receive at a time
      RECEIVE_WINDOW = 1024

      # Continuously receive and asynchronously handle data
      def run
        while data = @socket.recv(RECEIVE_WINDOW)
          async.handle_data(data)
        end
      end

      # Buffers incoming data and handles messages accordingly
      def handle_data(data)
        @buffer << data
        while message = Listen::TCP::Message.from_buffer(@buffer)
          handle_message(message)
        end
      end

      # Handles incoming message by notifying of path changes
      def handle_message(message)
        message.object.each do |change, paths|
          paths.each do |path|
            _notify_change(path, change: change.to_sym)
          end
        end
      end

    end

  end
end
