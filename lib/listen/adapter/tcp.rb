require 'celluloid/io'

require 'listen/tcp/message'

module Listen
  module Adapter
    # Adapter to receive file system modifications over TCP
    class TCP < Base
      OS_REGEXP = // # match any

      include Celluloid::IO

      finalizer :finalize

      attr_reader :buffer, :socket

      # Initializes and starts a Celluloid::IO-powered TCP-recipient
      def start
        attempts = 3
        @socket = TCPSocket.new(listener.host, listener.port)
        @buffer = ''
        async.run
      rescue Celluloid::Task::TerminatedError
        _log :debug, "TCP adapter was terminated: #{$!.inspect}"
      rescue Errno::ECONNREFUSED
        sleep 1
        attempts -= 1
        _log :warn, "TCP.start: #{$!.inspect}"
        retry if retries > 0
        _log :error, "TCP.start: #{$!.inspect}:#{$@.join("\n")}"
        raise
      rescue
        _log :error, "TCP.start: #{$!.inspect}:#{$@.join("\n")}"
        raise
      end

      # Cleans up buffer and socket
      def finalize
        @buffer = nil
        return unless @socket

        @socket.close
        @socket = nil
      end

      # Number of bytes to receive at a time
      RECEIVE_WINDOW = 1024

      # Continuously receive and asynchronously handle data
      def run
        while (data = @socket.recv(RECEIVE_WINDOW))
          async.handle_data(data)
        end
      end

      # Buffers incoming data and handles messages accordingly
      def handle_data(data)
        @buffer << data
        while (message = Listen::TCP::Message.from_buffer(@buffer))
          handle_message(message)
        end
      rescue
        _log :error, "TCP.handle_data crashed: #{$!}:#{$@.join("\n")}"
        raise
      end

      # Handles incoming message by notifying of path changes
      def handle_message(message)
        type, modification, path, _ = message.object
        _log :debug, "TCP: #{[type,modification,path].inspect}"
        _notify_change(type.to_sym, path, change: modification.to_sym)
      end

      def self.local_fs?
        false
      end
    end
  end
end
