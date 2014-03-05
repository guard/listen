require 'celluloid'
require 'listen/listener'
require 'listen/tcp/listener'

module Listen
  class << self
    attr_accessor :stopping

    # Listens to file system modifications on a either single directory or multiple directories.
    #
    # When :forward_to is specified, this listener will broadcast modifications over TCP.
    #
    # @param (see Listen::Listener#new)
    #
    # @yield [modified, added, removed] the changed files
    # @yieldparam [Array<String>] modified the list of modified files
    # @yieldparam [Array<String>] added the list of added files
    # @yieldparam [Array<String>] removed the list of removed files
    #
    # @return [Listen::Listener] the listener
    #
    def to(*args, &block)
      boot_celluloid
      @stopping = false
      options = args.last.is_a?(Hash) ? args.last : {}
      if target = options.delete(:forward_to)
        TCP::Listener.new(target, :broadcaster, *args, &block)
      else
        Listener.new(*args, &block)
      end
    end

    # Stop all listeners & Celluloid
    # Use it for testing purpose or when you are sure that Celluloid could be ended.
    #
    def stop
      Celluloid.shutdown
    end

    # Listens to file system modifications broadcast over TCP.
    #
    # @param [String/Fixnum] target to listen on (hostname:port or port)
    #
    # @yield [modified, added, removed] the changed files
    # @yieldparam [Array<String>] modified the list of modified files
    # @yieldparam [Array<String>] added the list of added files
    # @yieldparam [Array<String>] removed the list of removed files
    #
    # @return [Listen::Listener] the listener
    #
    def on(target, *args, &block)
      TCP::Listener.new(target, :recipient, *args, &block)
    end

    private

    def boot_celluloid
      Celluloid.boot unless Celluloid.running?
    end
  end
end
