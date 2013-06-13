module Listen
  class Listener
    include Celluloid

    attr_reader :options, :directories, :paused, :block

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
      @options     = _set_options(args.last.is_a?(Hash) ? args.pop : {})
      @directories = args.flatten.map { |path| Pathname.new(path) }
      @block       = block
    end

    # Starts the listener by initializing the adapter and building
    # the directory record concurrently, then it starts the adapter to watch
    # for changes. The current thread is not blocked after starting.
    #
    def start
      _init_actors
      adapter.async.start
      _wait_for_changes
      unpause
    end

    def stop
      Actor.kill(adapter)
      Actor[:change_pool].terminate
      Actor[:record].terminate
      Actor[:listener].terminate
    end

    def pause
      @paused = true
    end

    def unpause
      @paused = false
    end

    def paused?
      @paused == true
    end

    def listen?
      @paused == false
    end

    def adapter
      Actor[:adapter]
    end

    private

    def _set_options(options = {})
      options[:latency] ||= nil
      options[:force_polling] ||= false
      options[:polling_fallback_message] ||= nil
      options
    end

    def _init_actors
      Actor[:change_pool] = Change.pool
      Actor[:record] = Record.new
      Actor[:adapter] = Adapter.new
    end

    def _wait_for_changes
      async._receive_changes
      every(0.1) do
        changes = _pop_changes
        unless changes.values.all?(&:empty?)
          block.call(changes[:modified], changes[:added], changes[:removed])
        end
      end
    end

    def _receive_changes
      @changes = []
      loop { @changes << receive }
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
