require 'logger'
require 'listen/logger'
require 'listen/listener'

require 'listen/internals/thread_pool'

# Set up logging by default first time file is requried
#
Listen.logger ||= Logger.new(STDERR)

if Listen.logger
  debugging = ENV['LISTEN_GEM_DEBUGGING']

  Listen.logger.level =
    case debugging.to_s
    when /2/
      ::Logger::DEBUG
    when /true|yes|1/i
      ::Logger::INFO
    else
      ::Logger::ERROR
    end

  Listen.logger.info "Listen loglevel set to: #{Listen.logger.level}"
  Listen.logger.info "Listen version: #{Listen::VERSION}"
end

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
