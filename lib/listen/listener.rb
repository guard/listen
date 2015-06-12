require 'pathname'

require 'listen/version'
require 'listen/adapter'
require 'listen/change'
require 'listen/record'

require 'listen/silencer'
require 'listen/silencer/controller'

require 'listen/queue_optimizer'

require 'English'

require 'listen/internals/logging'


require 'listen/event_processor'


module Listen
  class Listener
    include Celluloid::FSM

    attr_accessor :block

    attr_reader :silencer

    # TODO: deprecate
    attr_reader :options, :directories
    attr_reader :registry, :supervisor


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
      @options = _init_options(args.last.is_a?(Hash) ? args.pop : {})

      # Setup logging first
      if Celluloid.logger
        Celluloid.logger.level = _debug_level
        _info "Celluloid loglevel set to: #{Celluloid.logger.level}"
        _info "Listen version: #{Listen::VERSION}"
      end

      @silencer = Silencer.new
      @silencer_controller = Silencer::Controller.new(@silencer, @options)

      @directories = args.flatten.map { |path| Pathname.new(path).realpath }
      @event_queue = Queue.new
      @block = block
      @registry = Celluloid::Registry.new

      optimizer_config = QueueOptimizer::Config.new(@adapter.class, @silencer)
      @queue_optimizer = QueueOptimizer.new(optimizer_config)

      transition :stopped
    end

    default_state :initializing

    state :initializing, to: :stopped
    state :paused, to: [:processing, :stopped]

    state :stopped, to: [:processing] do
      _stop_wait_thread
      if @supervisor
        @supervisor.terminate
        @supervisor = nil
      end
    end

    state :processing, to: [:paused, :stopped] do
      if wait_thread # means - was paused
        _wakeup_wait_thread
      else
        self.last_queue_event_time = nil
        _start_wait_thread
        _init_actors

        begin
          start = Time.now.to_f
          # Note: make sure building is finished before starting adapter (for
          # consistent results both in specs and normal usage)
          fs_changes.values.map(&:record).map(&:build)
          Listen::Logger.info "Record.build(): #{Time.now.to_f - start} seconds"
        rescue
          Listen::Logger.warn "build crashed: #{$ERROR_INFO.inspect}"
          raise
        end

        _start_adapter
      end
    end

    # Starts processing events and starts adapters
    # or resumes invoking callbacks if paused
    def start
      transition :processing
    end

    # TODO: depreciate
    alias_method :unpause, :start

    # Stops processing and terminates all actors
    def stop
      transition :stopped
    end

    # Stops invoking callbacks (messages pile up)
    def pause
      transition :paused
    end

    # processing means callbacks are called
    def processing?
      state == :processing
    end

    def paused?
      state == :paused
    end

    # TODO: deprecate
    alias_method :listen?, :processing?

    # TODO: deprecate
    def paused=(value)
      transition value ? :paused : :processing
    end

    # TODO: deprecate
    alias_method :paused, :paused?

    # Add files and dirs to ignore on top of defaults
    #
    # (@see Listen::Silencer for default ignored files and dirs)
    #
    def ignore(regexps)
      @silencer_controller.append_ignores(regexps)
    end

    # Replace default ignore patterns with provided regexp
    def ignore!(regexps)
      @silencer_controller.replace_with_bang_ignores(regexps)
    end

    # Listen only to files and dirs matching regexp
    def only(regexps)
      @silencer_controller.replace_with_only(regexps)
    end

    def async(type)
      proxy = sync(type)
      proxy ? proxy.async : nil
    end

    def sync(type)
      @registry[type]
    end

    def queue(type, change, dir, path, options = {})
      fail "Invalid type: #{type.inspect}" unless [:dir, :file].include? type
      fail "Invalid change: #{change.inspect}" unless change.is_a?(Symbol)
      fail "Invalid path: #{path.inspect}" unless path.is_a?(String)
      if @options[:relative]
        dir = begin
                cwd = Pathname.pwd
                dir.relative_path_from(cwd)
              rescue ArgumentError
                dir
              end
      end
      event_queue << [type, change, dir, path, options]

      self.last_queue_event_time = Time.now.to_f
      _wakeup_wait_thread unless state == :paused
    end

    def record_for(dir)
      fs_changes[dir.to_s].record
    end

    private

    include Internals::Logging

    def _init_options(options = {})
      {
        # Listener options
        debug: false,
        wait_for_delay: 0.1,
        relative: false,

        # Backend selecting options
        force_polling: false,
        polling_fallback_message: nil,

      }.merge(options)
    end

    def _debug_level
      debugging = ENV['LISTEN_GEM_DEBUGGING'] || options[:debug]
      case debugging.to_s
      when /2/
        Logger::DEBUG
      when /true|yes|1/i
        Logger::INFO
      else
        Logger::ERROR
      end
    end

    def _init_actors
      adapter_options = { mq: self, directories: directories }

      @supervisor = Celluloid::SupervisionGroup.run!(registry)

      # TODO: broadcaster should be a separate plugin
      if @tcp_mode == :broadcaster
        require 'listen/tcp/broadcaster'

        # TODO: pass a TCP::Config class to make sure host and port are properly
        # passed, even when nil
        supervisor.add(TCP::Broadcaster, as: :broadcaster, args: [@host, @port])

        # TODO: should be auto started, because if it crashes
        # a new instance is spawned by supervisor, but it's 'start' isn't
        # called
        registry[:broadcaster].start
      elsif @tcp_mode == :recipient
        # TODO: adapter options should be configured in Listen.{on/to}
        adapter_options.merge!(host: @host, port: @port)
      end

      # TODO: refactor
      valid_adapter_options = _adapter_class.const_get(:DEFAULTS).keys
      valid_adapter_options.each do |key|
        adapter_options.merge!(key => options[key]) if options.key?(key)
      end

      supervisor.add(_adapter_class, as: :adapter, args: [adapter_options])
    end

    def _wait_for_changes(config)
      latency = options[:wait_for_delay]
      EventProcessor.new(config).loop_for(latency)
    rescue StandardError => ex
      msg = "exception while processing events: #{ex}"\
        " Backtrace:\n -- #{ex.backtrace * "\n -- "}"
      Listen::Logger.error(msg)
    end

    def _silenced?(path, type)
      @silencer.silenced?(path, type)
    end

    def _start_adapter
      # Don't run async, because configuration has to finish first
      adapter = sync(:adapter)
      adapter.start
    end

    def _adapter_class
      @adapter_class ||= Adapter.select(options)
    end

    attr_reader :adapter
    attr_reader :queue_optimizer
    attr_reader :event_queue
    attr_reader :fs_changes

    attr_accessor :last_queue_event_time

    attr_reader :wait_thread

    def _start_wait_thread
      config = EventProcessor::Config.new(self, event_queue, @queue_optimizer)
      @wait_thread = Internals::ThreadPool.add { _wait_for_changes(config) }
    end

    def _wakeup_wait_thread
      wait_thread.wakeup if wait_thread && wait_thread.alive?
    end

    def _stop_wait_thread
      return unless wait_thread
      if wait_thread.alive?
        wait_thread.wakeup
        wait_thread.join
      end
      @wait_thread = nil
    end

    def _queue_raw_change(type, dir, rel_path, options)
      _debug { "raw queue: #{[type, dir, rel_path, options].inspect}" }
      fs_changes[dir.to_s].change(type, rel_path, options)
    rescue RuntimeError
      _error_exception "_queue_raw_change exception %s:\n%s:\n"
      raise
    end
  end
end
