require 'pathname'
require 'listen/adapter'
require 'listen/change'
require 'listen/record'
require 'listen/silencer'
require 'English'

module Listen
  class Listener

    include Celluloid::FSM

    attr_accessor :options, :directories, :paused, :changes, :block, :stopping
    attr_accessor :registry, :supervisor

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
      transition :initializing
      @options     = _init_options(args.last.is_a?(Hash) ? args.pop : {})

      # Handle TCP options here
      @tcp_mode = nil
      if [:recipient, :broadcaster].include? args[1]
        require 'listen/tcp'
        target = args.shift
        unless target
          fail ArgumentError, 'TCP::Listener requires target to be given'
        end
        @tcp_mode = args.shift
        @host = 'localhost' if @tcp_mode == :recipient
        if target.is_a? Fixnum
          @port = target
        else
          @host, @port = target.split(':')
          @port = @port.to_i
        end

        @options[:force_tcp] = true if @tcp_mode == :recipient
      end

      @directories = args.flatten.map { |path| Pathname.new(path).realpath }
      @queue = Queue.new
      @block       = block
      @registry    = Celluloid::Registry.new
      Celluloid.logger.level = _debug_level

      _log :info, "Celluloid loglevel set to: #{Celluloid.logger.level}"
      transition :stopped
    end

    default_state :initializing

    state :initializing, to: :stopped
    state :paused, to: [:processing, :stopped]

    state :stopped, to: [:processing] do
      if wait_thread
        if wait_thread.alive?
          wait_thread.wakeup
          wait_thread.join
        end
        @wait_thread = nil
      end

      if @supervisor
        @supervisor.terminate
        @supervisor = nil
      end
    end

    state :processing, to: [:paused, :stopped] do
      if wait_thread
        # resume if paused
        wait_thread.wakeup if wait_thread.alive?
      else
        @last_queue_event_time = nil
        @wait_thread = Thread.new { _wait_for_changes }

        _init_actors

        # Note: make sure building is finished before starting adapter (for
        # consistent results both in specs and normal usage)
        registry[:record].build

        _start_adapter
      end
    end

    # Starts processing events and starts adapters
    def start
      transition :processing
    end

    # Stops processing and terminates all actors
    def stop
      transition :stopped
    end

    # Stops invoking callbacks (messages pile up)
    def pause
      transition :paused
    end

    def paused=(value)
      if value
        transition :paused unless state == :paused
      else
        transition :processing unless state == :processing
      end
    end

    # Resumes invoking callbacks
    def unpause
      transition :processing
    end

    def paused?
      state == :paused
    end

    # TODO: deprecate and alias to processing?
    def listen?
      state == :processing
    end

    def processing?
      state == :processing
    end

    # Adds ignore patterns to the existing one
    #
    # @see DEFAULT_IGNORED_DIRECTORIES and DEFAULT_IGNORED_EXTENSIONS in
    #   Listen::Silencer)
    #
    # @param [Regexp, Array<Regexp>] new ignoring patterns.
    #
    def ignore(regexps)
      @options[:ignore] = [options[:ignore], regexps]
      registry[:silencer] = Silencer.new(self)
    end

    # Overwrites ignore patterns
    #
    # @see DEFAULT_IGNORED_DIRECTORIES and DEFAULT_IGNORED_EXTENSIONS in
    #   Listen::Silencer)
    #
    # @param [Regexp, Array<Regexp>] new ignoring patterns.
    #
    def ignore!(regexps)
      @options.delete(:ignore)
      @options[:ignore!] = regexps
      registry[:silencer] = Silencer.new(self)
    end

    # Sets only patterns, to listen only to specific regexps
    #
    # @param [Regexp, Array<Regexp>] new ignoring patterns.
    #
    def only(regexps)
      @options[:only] = regexps
      registry[:silencer] = Silencer.new(self)
    end

    def async(type)
      proxy = sync(type)
      proxy ? proxy.async : nil
    end

    def sync(type)
      @registry[type]
    end

    def queue(type, change, path, options = {})
      fail "Invalid type: #{type.inspect}" unless [:dir, :file].include? type
      fail "Invalid change: #{change.inspect}" unless change.is_a?(Symbol)
      @queue << [type, change, path, options]

      @last_queue_event_time = Time.now.to_f

      unless state == :paused
        wait_thread.wakeup if wait_thread && wait_thread.alive?
      end

      return unless @tcp_mode == :broadcaster

      message = TCP::Message.new(type, change, path, options)
      registry[:broadcaster].async.broadcast(message.payload)
    end

    def silencer
      @registry[:silencer]
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
      # TODO: remove? (since there are BSD warnings anyway)
      bsd = RbConfig::CONFIG['host_os'] =~ /bsd|dragonfly/
      return Logger::DEBUG if bsd

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
      @supervisor = Celluloid::SupervisionGroup.run!(registry)
      supervisor.add(Silencer, as: :silencer, args: self)
      supervisor.add(Record, as: :record, args: self)
      supervisor.pool(Change, as: :change_pool, args: self)

      if @tcp_mode == :broadcaster
        require 'listen/tcp/broadcaster'
        supervisor.add(TCP::Broadcaster, as: :broadcaster, args: [@host, @port])

        # TODO: should be auto started, because if it crashes
        # a new instance is spawned by supervisor, but it's 'start' isn't
        # called
        registry[:broadcaster].start
      end

      supervisor.add(_adapter_class, as: :adapter, args: self)
    end

    def _wait_for_changes
      latency = options[:wait_for_delay]

      loop do
        break if state == :stopped

        if state == :paused or @queue.empty?
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

    def _smoosh_changes(changes)
      # TODO: adapter could be nil at this point (shutdown)
      if _adapter_class.local_fs?
        cookies = changes.group_by do |_, _, _, options|
          (options || {})[:cookie]
        end
        _squash_changes(_reinterpret_related_changes(cookies))
      else
        smooshed = { modified: [], added: [], removed: [] }
        changes.each { |_, change, path, _| smooshed[change] << path.to_s }
        smooshed.tap { |s| s.each { |_, v| v.uniq! } }
      end
    end

    def _squash_changes(changes)
      actions = changes.group_by(&:last).map do |path, action_list|
        [_logical_action_for(path, action_list.map(&:first)), path.to_s]
      end
      _log :info, "listen: raw changes: #{actions.inspect}"

      { modified: [], added: [], removed: [] }.tap do |squashed|
        actions.each do |type, path|
          squashed[type] << path unless type.nil?
        end
        _log :info, "listen: final changes: #{squashed.inspect}"
      end
    end

    def _logical_action_for(path, actions)
      actions << :added if actions.delete(:moved_to)
      actions << :removed if actions.delete(:moved_from)

      modified = actions.detect { |x| x == :modified }
      _calculate_add_remove_difference(actions, path, modified)
    end

    def _calculate_add_remove_difference(actions, path, default_if_exists)
      added = actions.count { |x| x == :added }
      removed = actions.count { |x| x == :removed }
      diff = added - removed

      # TODO: avoid checking if path exists and instead assume the events are
      # in order (if last is :removed, it doesn't exist, etc.)
      if path.exist?
        if diff > 0
          :added
        elsif diff.zero? && added > 0
          :modified
        else
          default_if_exists
        end
      else
        diff < 0 ? :removed : nil
      end
    end

    # remove extraneous rb-inotify events, keeping them only if it's a possible
    # editor rename() call (e.g. Kate and Sublime)
    def _reinterpret_related_changes(cookies)
      table = { moved_to: :added, moved_from: :removed }
      cookies.map do |_, changes|
        file = _detect_possible_editor_save(changes)
        if file
          [[:modified, file]]
        else
          not_silenced = changes.reject do |type, _, path, _|
            _silenced?(path, type)
          end
          not_silenced.map do |_, change, path, _|
            [table.fetch(change, change), path]
          end
        end
      end.flatten(1)
    end

    def _detect_possible_editor_save(changes)
      return unless changes.size == 2

      from_type = from_change = from = nil
      to_type = to_change = to = nil

      changes.each do |data|
        case data[1]
        when :moved_from
          from_type, from_change, from, _ = data
        when :moved_to
          to_type, to_change, to, _ = data
        else
          return nil
        end
      end

      return unless from && to

      # Expect an ignored moved_from and non-ignored moved_to
      # to qualify as an "editor modify"
      _silenced?(from, from_type) && !_silenced?(to, to_type) ? to : nil
    end

    def _silenced?(path, type)
      registry[:silencer].silenced?(path, type)
    end

    def _start_adapter
      # Don't run async, because configuration has to finish first
      registry[:adapter].start
    end

    def _log(type, message)
      Celluloid.logger.send(type, message)
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

      # TODO: condition not tested, but too complex to test ATM
      block.call(*result) unless result.all?(&:empty?)
    end

    attr_reader :wait_thread
  end
end
