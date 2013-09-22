require 'listen/tcp/broadcaster'
require 'listen/tcp/message'

module Listen
  module TCP
    class Listener < Listen::Listener

      DEFAULT_HOST = 'localhost'

      attr_reader :host, :mode, :port

      # Initializes a listener to broadcast or receive modifications over TCP
      #
      # @param [String/Fixnum] target to listen on (hostname:port or port)
      # @param [Symbol] mode (either :broadcaster or :recipient)
      #
      # @param (see Listen::Listener#new)
      #
      def initialize target, mode, *args, &block
        self.mode = mode
        self.target = target

        super *args, &block
      end

      def broadcaster?
        @mode == :broadcaster
      end

      def recipient?
        @mode == :recipient
      end

      # Initializes and starts TCP broadcaster
      def start
        super
        if broadcaster?
          Celluloid::Actor[:listen_broadcaster] = Broadcaster.new(host, port)
        end
      end

      # Stops TCP broadcaster
      def stop
        super
        if broadcaster?
          Celluloid::Actor[:listen_broadcaster].terminate
        end
      end

      # Hook to broadcast changes over TCP while honouring
      # paused-state and invoking the original callback block
      BROADCASTER_HOOK = Proc.new { |*args|
        next if @paused
        message = Message.new(args)
        Celluloid::Actor[:listen_broadcaster].async.broadcast(message.payload)
        yield @block if @block
      }

      # When broadcasting, activates the above hook
      def block
        if broadcaster?
          BROADCASTER_HOOK
        else
          super
        end
      end

      private

      # Sets listener mode
      #
      # @param [Symbol] mode (either :broadcaster or :recipient)
      #
      def mode= mode
        unless [:broadcaster, :recipient].include? mode
          raise ArgumentError, 'TCP::Listener requires mode to be either :broadcaster or :recipient'
        end
        @mode = mode
      end

      # Sets listener target
      #
      # @param [String/Fixnum] target to listen on (hostname:port or port)
      #
      def target= target
        unless target
          raise ArgumentError, 'TCP::Listener requires target to be given'
        end

        @host = DEFAULT_HOST

        if target.is_a? Fixnum
          @port = target
        else
          @host, @port = target.split(':')
          @port = @port.to_i
        end
      end

    end
  end
end
