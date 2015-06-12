require 'celluloid'
require 'listen/listener'

require 'listen/internals/thread_pool'

module Listen
  class << self
    # Listens to file system modifications on a either single directory or
    # multiple directories.
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
      @listeners ||= []
      Listener.new(*args, &block).tap do |listener|
        @listeners << listener
      end
    end

    # This is used by the `listen` binary to handle Ctrl-C
    #
    def stop
      Internals::ThreadPool.stop
      @listeners ||= []

      # TODO: should use a mutex for this
      @listeners.each do |listener|
        # call stop to halt the main loop
        listener.stop
      end
      @listeners = nil
    end
  end
end
