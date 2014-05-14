require 'pathname'
require 'listen/adapter'
require 'listen/change'
require 'listen/record'
require 'listen/silencer'
require 'English'

module Listen
  class Listener
    attr_accessor :options, :directories, :paused, :changes, :block, :stopping
    attr_accessor :registry, :supervisor

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
      @registry    = Celluloid::Registry.new
      _init_debug
    end

    # Starts the listener by initializing the adapter and building
    # the directory record concurrently, then it starts the adapter to watch
    # for changes. The current thread is not blocked after starting.
    #
    def start
      _init_actors
      unpause
      @stopping = false
      registry[:adapter].async.start
      Thread.new { _wait_for_changes }
    end

    # Terminates all Listen actors and kill the adapter.
    #
    def stop
      @stopping = true
      supervisor.terminate
    end

    # Pauses listening callback (adapter still running)
    #
    def pause
      @paused = true
    end

    # Unpauses listening callback
    #
    def unpause
      registry[:record].build
      @paused = false
    end

    # Returns true if Listener is paused
    #
    # @return [Boolean]
    #
    def paused?
      @paused == true
    end

    # Returns true if Listener is neither paused nor stopped
    #
    # @return [Boolean]
    #
    def listen?
      @paused == false && @stopping == false
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

    private

    def _init_options(options = {})
      { debug: false,
        latency: nil,
        wait_for_delay: 0.1,
        force_polling: false,
        polling_fallback_message: nil }.merge(options)
    end

    def _init_debug
      if options[:debug] || ENV['LISTEN_GEM_DEBUGGING'] =~ /true|1/i
        if RbConfig::CONFIG['host_os'] =~ /bsd|dragonfly/
          Celluloid.logger.level = Logger::INFO
        else
          # BSDs silently fail ;;(
          Celluloid.logger.level = Logger::DEBUG
        end
      else
        Celluloid.logger.level = Logger::FATAL
      end
    end

    def _init_actors
      @supervisor = Celluloid::SupervisionGroup.run!(registry)
      supervisor.add(Silencer, as: :silencer, args: self)
      supervisor.add(Record, as: :record, args: self)
      supervisor.pool(Change, as: :change_pool, args: self)

      adapter_class = Adapter.select(options)
      supervisor.add(adapter_class, as: :adapter, args: self)
    end

    def _wait_for_changes
      loop do
        break if @stopping

        changes = []
        begin
          sleep options[:wait_for_delay] # wait for changes to accumulate
          new_changes = _pop_changes
          changes += new_changes
        end until new_changes.empty?
        unless changes.empty?
          hash = _smoosh_changes(changes)
          block.call(hash[:modified], hash[:added], hash[:removed])
        end
      end
    rescue => ex
      Kernel.warn "[Listen warning]: Change block raised an exception: #{$!}"
      Kernel.warn "Backtrace:\n\t#{ex.backtrace.join("\n\t")}"
    end

    def _pop_changes
      popped = []
      popped << @changes.shift until @changes.empty?
      popped
    end

    def _smoosh_changes(changes)
      if registry[:adapter].class.local_fs?
        cookies = changes.group_by { |x| x[:cookie] }
        _squash_changes(_reinterpret_related_changes(cookies))
      else
        smooshed = { modified: [], added: [], removed: [] }
        changes.map(&:first).each { |type, path| smooshed[type] << path.to_s }
        smooshed.tap { |s| s.each { |_, v| v.uniq! } }
      end
    end

    def _squash_changes(changes)
      actions = changes.group_by(&:last).map do |path, action_list|
        [_logical_action_for(path, action_list.map(&:first)), path.to_s]
      end
      Celluloid.logger.info "listen: raw changes: #{actions.inspect}"

      { modified: [], added: [], removed: [] }.tap do |squashed|
        actions.each do |type, path|
          squashed[type] << path unless type.nil?
        end
        Celluloid.logger.info "listen: final changes: #{squashed.inspect}"
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
          not_silenced = changes.map(&:first).reject do |_, path|
            _silenced?(path)
          end
          not_silenced.map { |type, path| [table.fetch(type, type), path] }
        end
      end.flatten(1)
    end

    def _detect_possible_editor_save(changes)
      return unless changes.size == 2

      from, to = changes.sort { |x, y| x.keys.first <=> y.keys.first }
      from, to = from[:moved_from], to[:moved_to]
      return unless from && to

      # Expect an ignored moved_from and non-ignored moved_to
      # to qualify as an "editor modify"
      _silenced?(from) && !_silenced?(to) ? to : nil
    end

    def _silenced?(path)
      type = path.directory? ? 'Dir' : 'File'
      registry[:silencer].silenced?(path, type)
    end
  end
end
