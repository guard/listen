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
      def initialize(target, mode, *args, &block)
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
          supervisor.add(Broadcaster, as: :broadcaster, args: [host, port])
          registry[:broadcaster].start
        end
      end

      # Hook to broadcast changes over TCP
      def block
        if broadcaster?
          Proc.new { |modified, added, removed|

            # Honour paused and stopped states
            next if @paused || @stopping

            # Broadcast changes as a hash (see Listen::Adapter::TCP#handle_message)
            message = Message.new(modified: modified, added: added, removed: removed)
            registry[:broadcaster].async.broadcast(message.payload)

            # Invoke the original callback block
            @block.call(modified, added, removed) if @block
          }
        else
          super
        end
      end

      private

      def _init_options(options = {})
        options = super(options)
        options[:force_tcp] = true if recipient?
        options
      end

      # Sets listener mode
      #
      # @param [Symbol] mode (either :broadcaster or :recipient)
      #
      def mode=(mode)
        unless [:broadcaster, :recipient].include? mode
          raise ArgumentError, 'TCP::Listener requires mode to be either :broadcaster or :recipient'
        end
        @mode = mode
      end

      # Sets listener target
      #
      # @param [String/Fixnum] target to listen on (hostname:port or port)
      #
      def target=(target)
        unless target
          raise ArgumentError, 'TCP::Listener requires target to be given'
        end

        @host = DEFAULT_HOST if recipient?

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
