require 'listen/adapter'
require 'listen/change'

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
      # @directories = _set_directories(args.flatten)
      @block       = block

      # initialize_directories_and_directories_records(directories)
      # initialize_relative_paths_usage(options)
      # ignore(*options.delete(:ignore))
      # filter(*options.delete(:filter))
    end

    # Starts the listener by initializing the adapter and building
    # the directory record concurrently, then it starts the adapter to watch
    # for changes. The current thread is not blocked after starting.
    #
    def start
      # async.build_directories_records
      _start_adapter
      _wait_for_changes
      @paused = false
    end

    def stop
      Celluloid::Actor.kill(adapter)
      Actor[:listener].terminate
    end

    def pause
      @paused = true
    end

    def unpause
      # async.build_directories_records
      @paused = false
    end

    def paused?
      paused
    end

    private

    def _set_options(options = {})
      options[:latency] ||= nil
      options[:force_polling] ||= false
      options[:polling_fallback_message] ||= nil
      options
    end

    def _start_adapter
      Actor[:adapter] = Adapter.new
      Actor[:adapter].async.start
    end

    def _wait_for_changes
      async._receive_changes
      every(0.1) do
        changes = _new_changes
        unless changes.values.all?(&:empty?)
          block.call(changes[:modified], changes[:added], changes[:removed])
        end
      end
    end

    def _receive_changes
      @changes = []
      loop { @changes << receive }
    end

    def _new_changes
      changes = { modified: [], added: [], removed: [] }
      until @changes.empty?
        change = @changes.pop
        changes.keys.each { |key| changes[key] += change[key] }
      end
      changes
    end

    # Initializes the directories to watch as well as the directories records.
    #
    # @see Listen::DirectoryRecord
    #
    # def initialize_directories_and_directories_records(directories)
    #   @directories = directories.map { |d| Pathname.new(d).realpath.to_s }
    #   @directories_records = directories.map { |d| DirectoryRecord.new(d) }
    # end

    # Initializes whether or not using relative paths.
    #
    # def initialize_relative_paths_usage(options)
    #   @use_relative_paths = directories.one? && options.delete(:relative_paths) { true }
    # end

    # Build the directory record concurrently and initialize the adapter.
    #
    # def setup
    #   t = Thread.new { build_directories_records }
    #   @adapter = initialize_adapter
    #   t.join
    # end

    # Initializes an adapter passing it the callback and adapters' options.
    #
    # def initialize_adapter
    #   callback = lambda { |changed_directories, options| self.on_change(changed_directories, options) }
    #   Adapter.select_and_initialize(directories, adapter_options, &callback)
    # end

    # Build the watched directories' records.
    #
    # def _build_directories_records
    #   directories_records.each { |r| r.build }
    # end

    # Returns the sum of all the changes to the directories records
    #
    # @param (see Listen::DirectoryRecord#fetch_changes)
    #
    # @return [Hash] the changes
    #
    # def _fetch_records_changes(directories_to_search)
    #   directories_records.inject({}) do |h, r|
    #     # directory records skips paths outside their range, so passing the
    #     # whole `directories` array is not a problem.
    #     record_changes = r.fetch_changes(directories_to_search,
    #       relative_paths: use_relative_paths,
    #       recursive: recursive
    #     )

    #     if h.empty?
    #       h.merge!(record_changes)
    #     else
    #       h.each { |k, v| h[k] += record_changes[k] }
    #     end

    #     h
    #   end
    # end

  end
end
