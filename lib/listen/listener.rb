require 'pathname'
require 'listen/adapter'
require 'listen/change'
require 'listen/record'
require 'listen/silencer'

module Listen
  class Listener
    attr_accessor :options, :directories, :paused, :changes, :block, :thread

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
      @directories = args.flatten.map { |path| Pathname.new(path).realpath }
      @changes     = []
      @block       = block
      _init_debug
    end

    # Starts the listener by initializing the adapter and building
    # the directory record concurrently, then it starts the adapter to watch
    # for changes. The current thread is not blocked after starting.
    #
    def start
      _signals_trap
      _init_actors
      unpause
      Celluloid::Actor[:listen_adapter].async.start
      @thread = Thread.new { _wait_for_changes }
    end

    # Terminates all Listen actors and kill the adapter.
    #
    def stop
      @stopping = true
      thread.join
    end

    # Pauses listening callback (adapter still running)
    #
    def pause
      @paused = true
    end

    # Unpauses listening callback
    #
    def unpause
      Celluloid::Actor[:listen_record].build
      @paused = false
    end

    # Returns true if Listener is paused
    #
    # @return [Boolean]
    #
    def paused?
      @paused == true
    end

    # Returns true if Listener is not paused
    #
    # @return [Boolean]
    #
    def listen?
      @paused == false
    end

    # Adds ignore patterns to the existing one (See DEFAULT_IGNORED_DIRECTORIES and DEFAULT_IGNORED_EXTENSIONS in Listen::Silencer)
    #
    # @param [Regexp, Hash<Regexp>] new ignoring patterns.
    #
    def ignore(regexps)
      @options[:ignore] = [options[:ignore], regexps]
      Celluloid::Actor[:listen_silencer] = Silencer.new(self)
    end

    # Overwrites ignore patterns (See DEFAULT_IGNORED_DIRECTORIES and DEFAULT_IGNORED_EXTENSIONS in Listen::Silencer)
    #
    # @param [Regexp, Hash<Regexp>] new ignoring patterns.
    #
    def ignore!(regexps)
      @options.delete(:ignore)
      @options[:ignore!] = regexps
      Celluloid::Actor[:listen_silencer] = Silencer.new(self)
    end

    private

    def _init_options(options = {})
      { debug: false,
        latency: nil,
        wait_for_delay: 0.1,
        force_polling: false,
        polling_fallback_message: nil }.merge(options)
    end

    def _init_debug
      if options[:debug]
        Celluloid.logger.level = Logger::INFO
      else
        Celluloid.logger = nil
      end
    end

    def _init_actors
      Celluloid::Actor[:listen_silencer]    = Silencer.new(self)
      Celluloid::Actor[:listen_change_pool] = Change.pool(args: self)
      Celluloid::Actor[:listen_adapter]     = Adapter.new(self)
      Celluloid::Actor[:listen_record]      = Record.new(self)
    end

    def _signals_trap
      return if defined?(JRUBY_VERSION)
      if Signal.list.keys.include?('INT')
        Signal.trap('INT') { stop }
      end
    end

    def _wait_for_changes
      loop do
        break if @stopping

        changes = _pop_changes
        unless changes.all? { |_,v| v.empty? }
          block.call(changes[:modified], changes[:added], changes[:removed])
        end
        sleep options[:wait_for_delay]
      end

      _terminate_actors
      exit
    rescue => ex
      Kernel.warn "[Listen warning]: Change block raised an exception: #{$!}"
      Kernel.warn "Backtrace:\n\t#{ex.backtrace.join("\n\t")}"
    end

    def _pop_changes
      changes = { modified: [], added: [], removed: [] }
      until @changes.empty?
        change = @changes.pop
        change.each { |k, v| changes[k] << v.to_s }
      end
      changes.each { |_, v| v.uniq! }
    end

    def _terminate_actors
      Celluloid::Actor[:listen_adapter].terminate
      Celluloid::Actor[:listen_silencer].terminate
      Celluloid::Actor[:listen_change_pool].terminate
      Celluloid::Actor[:listen_record].terminate
    end
  end
end
