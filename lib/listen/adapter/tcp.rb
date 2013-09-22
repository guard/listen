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
        # Passing a regular TCPSocket to Celluloid::IO's seems
        # to work around an issue with Errno::ECONNREFUSED on
        # local addresses
        @socket = TCPSocket.new ::TCPSocket.new(listener.host, listener.port)
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

      private

      # Number of bytes to receive at a time
      RECEIVE_WINDOW = 1024

      # Continuously receive and asynchronously handle data
      def run
        loop do
          async.handle_data(@socket.recv(RECEIVE_WINDOW))
        end
      end

      # Buffers incoming data and dispatches messages accordingly
      def handle_data data
        @buffer << data
        while message = Listen::TCP::Message.from_buffer(@buffer)
          message.object.flatten.each do |path|
            _notify_change(path, type: 'file')
          end
        end
      end

    end

  end
end
