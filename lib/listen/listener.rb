require 'listen/adapter'
require 'listen/change'
require 'listen/record'

module Listen
  class Listener
    attr_reader :options, :directories, :paused, :changes, :block

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
      @changes     = []
      @block       = block
    end

    # Starts the listener by initializing the adapter and building
    # the directory record concurrently, then it starts the adapter to watch
    # for changes. The current thread is not blocked after starting.
    #
    def start
      _init_actors
      _build_record_if_needed
      adapter.async.start
      Thread.new { _wait_for_changes }
      unpause
    end

    def stop
      Celluloid::Actor.kill(adapter)
      Celluloid::Actor[:change_pool].terminate
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
      Celluloid::Actor[:adapter]
    end

    def record
      Celluloid::Actor[:record]
    end

    private

    def _set_options(options = {})
      options[:latency]                  ||= nil
      options[:force_polling]            ||= false
      options[:polling_fallback_message] ||= nil
      options
    end

    def _init_actors
      Celluloid::Actor[:change_pool] = Change.pool(args: self)
      Celluloid::Actor[:adapter]     = Adapter.new(self)
      Celluloid::Actor[:record]      = Record.new if adapter.need_record?
    end

    def _build_record_if_needed
      record && record.build(directories)
    end

    def _wait_for_changes
      loop do
        sleep 0.1
        changes = _pop_changes
        unless changes.values.all?(&:empty?)
          block.call(changes[:modified], changes[:added], changes[:removed])
        end
      end
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
