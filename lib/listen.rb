require 'celluloid'
require 'listen/listener'

module Listen
  class << self
    attr_accessor :stopping

    # Listens to file system modifications on a either single directory or multiple directories.
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
      @stopping = false
      Listener.new(*args, &block)
    end

    # Stop all listeners
    #
    def stop
      @stopping = true
    end
  end
end
