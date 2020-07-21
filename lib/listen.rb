require 'logger'
require 'weakref'
require 'listen/logger'
require 'listen/listener'

require 'listen/internals/thread_pool'

# Always set up logging by default first time file is required
#
# NOTE: If you need to clear the logger completely, do so *after*
# requiring this file. If you need to set a custom logger,
# require the listen/logger file and set the logger before requiring
# this file.
Listen.setup_default_logger_if_unset

# Won't print anything by default because of level - unless you've set
# LISTEN_GEM_DEBUGGING or provided your own logger with a high enough level
Listen::Logger.info "Listen loglevel set to: #{Listen.logger.level}"
Listen::Logger.info "Listen version: #{Listen::VERSION}"

module Listen
  @listeners = Queue.new

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
      Listener.new(*args, &block).tap do |listener|
        @listeners.enq(WeakRef.new(listener))
      end
    end

    # This is used by the `listen` binary to handle Ctrl-C
    #
    def stop
      Internals::ThreadPool.stop

      while (listener = @listeners.deq(true))
        begin
          listener.stop
        rescue WeakRef::RefError
        end
      end
    rescue ThreadError
    end
  end
end
