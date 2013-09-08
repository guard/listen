require 'listen/adapter'
require 'listen/change'
require 'listen/record'

module Listen
  class Listener
    attr_accessor :options, :directories, :paused, :changes, :block

    RELATIVE_PATHS_WITH_MULTIPLE_DIRECTORIES_WARNING_MESSAGE = "The relative_paths option doesn't work when listening to multiple diretories."

    # Initializes the directories listener.
    #
    # @param [String] directory the directories to listen to
    # @param [Hash] options the listen options (see Listen::Listener::Options)
    #
    # @yield [modified, added, removed] the changed files
    # @yieldparam [Array<String>] modified the list of modified files
    # @yieldparam [Array<String>] added the list of added files
    # @yieldparam [Array<String>] removed the list of removed files
    #
    def initialize(*args, &block)
      @options     = _init_options(args.last.is_a?(Hash) ? args.pop : {})
      @directories = args.flatten.map { |path| Pathname.new(path) }
      @changes     = []
      @block       = block
    end

    # Starts the listener by initializing the adapter and building
    # the directory record concurrently, then it starts the adapter to watch
    # for changes. The current thread is not blocked after starting.
    #
    def start
      _init_actors
      unpause
      adapter.async.start
      Thread.new { _wait_for_changes }
    end

    def stop
      Celluloid::Actor.kill(adapter)
      Celluloid::Actor[:listen_change_pool].terminate
      record && record.terminate
    end

    def pause
      @paused = true
    end

    def unpause
      _build_record_if_needed
      @paused = false
    end

    def paused?
      @paused == true
    end

    def listen?
      @paused == false
    end

    def adapter
      Celluloid::Actor[:listen_adapter]
    end

    def record
      Celluloid::Actor[:listen_record]
    end

    private

    def _init_options(options = {})
      { latency: nil,
        force_polling: false,
        polling_fallback_message: nil }.merge(options)
    end

    def _init_actors
      Celluloid::Actor[:listen_change_pool] = Change.pool(args: self)
      Celluloid::Actor[:listen_adapter]     = Adapter.new(self)
      Celluloid::Actor[:listen_record]      = Record.new(self)
    end

    def _build_record_if_needed
      record && record.build
    end

    def _wait_for_changes
      loop do
        changes = _pop_changes
        unless changes.values.all?(&:empty?)
          block.call(
            changes[:modified].uniq,
            changes[:added].uniq,
            changes[:removed].uniq)
        end
        sleep 0.1
      end
    rescue => ex
      Kernel.warn "[Listen warning]: Change block raise an execption: #{$!}"
      Kernel.warn "Backtrace:\n\t#{ex.backtrace.join("\n\t")}"
    end

    def _pop_changes
      changes = { modified: [], added: [], removed: [] }
      until @changes.empty?
        change = @changes.pop
        change.each { |k, v| changes[k] << v.to_s }
      end
      changes
    end
  end
end
