require 'pathname'
require 'listen/adapter'
require 'listen/change'
require 'listen/record'
require 'listen/silencer'
require 'listen/queue_optimizer'
require 'English'

module Listen
  class Listener
    include Celluloid::FSM
    include QueueOptimizer

    attr_accessor :block

    attr_reader :silencer

    # TODO: deprecate
    attr_reader :options, :directories
    attr_reader :registry, :supervisor

    # TODO: deprecate
    # NOTE: these are VERY confusing (broadcast + recipient modes)
    attr_reader :host, :port

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
        _log :info, "Celluloid loglevel set to: #{Celluloid.logger.level}"
      end

      @silencer = Silencer.new
      _reconfigure_silencer({})

      @tcp_mode = nil
      if [:recipient, :broadcaster].include? args[1]
        target = args.shift
        @tcp_mode = args.shift
        _init_tcp_options(target)
      end

      @directories = args.flatten.map { |path| Pathname.new(path).realpath }
      @queue = Queue.new
      @block = block
      @registry = Celluloid::Registry.new

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
        @last_queue_event_time = nil
        _start_wait_thread
        _init_actors

        # Note: make sure building is finished before starting adapter (for
        # consistent results both in specs and normal usage)
        sync(:record).build

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
      _reconfigure_silencer(ignore: [options[:ignore], regexps])
    end

    # Replace default ignore patterns with provided regexp
    def ignore!(regexps)
      _reconfigure_silencer(ignore: [], ignore!: regexps)
    end

    # Listen only to files and dirs matching regexp
    def only(regexps)
      _reconfigure_silencer(only: regexps)
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
      @queue << [type, change, dir, path, options]

      @last_queue_event_time = Time.now.to_f
      _wakeup_wait_thread unless state == :paused

      return unless @tcp_mode == :broadcaster

      message = TCP::Message.new(type, change, dir, path, options)
      registry[:broadcaster].async.broadcast(message.payload)
    end

    private

    def _init_options(options = {})
      { debug: false,
        latency: nil,
        wait_for_delay: 0.1,
        force_polling: false,
        polling_fallback_message: nil }.merge(options)
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
      options = [mq: self, directories: directories]

      @supervisor = Celluloid::SupervisionGroup.run!(registry)
      supervisor.add(Record, as: :record, args: self)
      supervisor.pool(Change, as: :change_pool, args: self)

      # TODO: broadcaster should be a separate plugin
      if @tcp_mode == :broadcaster
        require 'listen/tcp/broadcaster'
        supervisor.add(TCP::Broadcaster, as: :broadcaster, args: [@host, @port])

        # TODO: should be auto started, because if it crashes
        # a new instance is spawned by supervisor, but it's 'start' isn't
        # called
        registry[:broadcaster].start
      elsif @tcp_mode == :recipient
        # TODO: adapter options should be configured in Listen.{on/to}
        options.first.merge!(host: @host, port: @port)
      end

      supervisor.add(_adapter_class, as: :adapter, args: options)
    end

    def _wait_for_changes
      latency = options[:wait_for_delay]

      loop do
        break if state == :stopped

        if state == :paused || @queue.empty?
          sleep
          break if state == :stopped
        end

        # Assure there's at least latency between callbacks to allow
        # for accumulating changes
        now = Time.now.to_f
        diff = latency + (@last_queue_event_time || now) - now
        if diff > 0
          sleep diff
          next
        end

        _process_changes unless state == :paused
      end
    rescue RuntimeError
      Kernel.warn "[Listen warning]: Change block raised an exception: #{$!}"
      Kernel.warn "Backtrace:\n\t#{$@.join("\n\t")}"
    end

    def _silenced?(path, type)
      @silencer.silenced?(path, type)
    end

    def _start_adapter
      # Don't run async, because configuration has to finish first
      adapter = sync(:adapter)
      adapter.start
    end

    def _log(type, message)
      Celluloid::Logger.send(type, message)
    end

    def _adapter_class
      @adapter_class ||= Adapter.select(options)
    end

    # for easier testing without sleep loop
    def _process_changes
      return if @queue.empty?

      @last_queue_event_time = nil

      changes = []
      while !@queue.empty?
        changes << @queue.pop
      end

      return if block.nil?

      hash = _smoosh_changes(changes)
      result = [hash[:modified], hash[:added], hash[:removed]]

      block_start = Time.now.to_f
      # TODO: condition not tested, but too complex to test ATM
      block.call(*result) unless result.all?(&:empty?)
      _log :debug, "Callback took #{Time.now.to_f - block_start} seconds"
    end

    attr_reader :wait_thread

    def _init_tcp_options(target)
      # Handle TCP options here
      require 'listen/tcp'
      fail ArgumentError, 'missing host/port for TCP' unless target

      if @tcp_mode == :recipient
        @host = 'localhost'
        @options[:force_tcp] = true
      end

      if target.is_a? Fixnum
        @port = target
      else
        @host, port = target.split(':')
        @port = port.to_i
      end
    end

    def _reconfigure_silencer(extra_options)
      @options.merge!(extra_options)

      # TODO: this should be directory specific
      rules = [:only, :ignore, :ignore!].map do |option|
        [option, @options[option]] if @options.key? option
      end

      @silencer.configure(Hash[rules.compact])
    end

    def _start_wait_thread
      @wait_thread = Thread.new { _wait_for_changes }
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
      _log :debug, "raw queue: #{[type, dir, rel_path, options].inspect}"

      unless (worker = async(:change_pool))
        _log :warn, 'Failed to allocate worker from change pool'
        return
      end

      worker.change(type, dir, rel_path, options)
    rescue RuntimeError
      _log :error, "#{__method__} crashed: #{$!}:#{$@.join("\n")}"
      raise
    end
  end
end
