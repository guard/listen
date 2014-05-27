require 'json'

module Listen
  module TCP
    class Message
      attr_reader :body, :object, :payload, :size

      HEADER_SIZE    = 4
      HEADER_FORMAT  = 'N'
      PAYLOAD_FORMAT = "#{HEADER_FORMAT}a*"

      # Initializes a new message
      #
      # @param [Object] object to initialize message with
      #
      def initialize(*args)
        self.object = args
      end

      # Generates message size and payload for given object
      def object=(obj)
        @object = obj
        @body = JSON.generate(@object)
        @size = @body.bytesize
        @payload = [@size, @body].pack(PAYLOAD_FORMAT)
      end

      # Extracts message size and loads object from given payload
      def payload=(payload)
        @payload = payload
        @size, @body = @payload.unpack(PAYLOAD_FORMAT)
        @object = JSON.parse(@body)
      end

      # Extracts a message from given buffer
      def self.from_buffer(buffer)
        if buffer.bytesize > HEADER_SIZE
          size = buffer.unpack(HEADER_FORMAT).first
          payload_size = HEADER_SIZE + size
          if buffer.bytesize >= payload_size
            payload = buffer.slice!(0...payload_size)
            new.tap do |message|
              message.payload = payload
            end
          end
        end
      end
    end
  end
end
