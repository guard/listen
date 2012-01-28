require 'find'
require 'listen/adapter'
require 'listen/adapters/polling'

module Listen
  class Listener
    attr_accessor :directory, :ignored_paths, :file_filters, :paths

    # Default paths that gets ignored by the listener
    DEFAULT_IGNORED_PATHS = %w[.bundle .git log tmp vendor]

    # Initialize the file listener.
    #
    # @param [String, Pathname] dir the directory to watch
    # @param [Hash] options the listen options
    # @option options [String] ignore a list of paths to ignore
    # @option options [Regexp] filter a list of regexps file filters
    #
    # @yield [modified, added, removed] the changed files
    # @yieldparam [Array<String>] modified the list of modified files
    # @yieldparam [Array<String>] added the list of added files
    # @yieldparam [Array<String>] removed the list of removed files
    #
    # @return [Listen::Listener] the file listener
    #
    def initialize(*args, &block)
      @directory     = args.first
      @ignored_paths = DEFAULT_IGNORED_PATHS
      @file_filters  = []
      @block         = block
      if args[1]
        @ignored_paths += Array(args[1][:ignore]) if args[1][:ignore]
        @file_filters  += Array(args[1][:filter]) if args[1][:filter]
      end
      @adapter = Adapter.select_and_initialize(self)
    end

    # Initialize the @paths and start the adapter.
    #
    def start
      init_paths
      @adapter.start
    end

    # Stop the adapter.
    #
    def stop
      @adapter.stop
    end

    # Add ignored path to the listener.
    #
    # @example Ignore some paths
    #   ignore ".git", ".svn"
    #
    # @param [Array<String>] paths a list of paths to ignore
    #
    # @return [Listen::Listener] the listener itself
    #
    def ignore(*paths)
      @ignored_paths.push(*paths)
      self
    end

    # Add file filters to the listener.
    #
    # @example Filter some files
    #   ignore /\.txt$/, /.*\.zip/
    #
    # @param [Array<Regexp>] regexps a list of regexps file filters
    #
    # @return [Listen::Listener] the listener itself
    #
    def filter(*regexps)
      @file_filters.push(*regexps)
      self
    end

    # Set change callback block to the listener.
    #
    # @example Filter some files
    #   callback = lambda { |modified, added, removed| ... }
    #   change &callback
    #
    # @param [Block] block a block callback called on changes
    #
    # @return [Listen::Listener] the listener itself
    #
    def change(&block) # modified, added, removed
      @block = block
      self
    end

    # Call @block callback when there is a diff in the passed directory.
    #
    # @param [String] directory the directory to diff
    #
    def on_change(directory)
      changes = diff(directory)
      unless changes.values.all? { |paths| paths.empty? }
        @block.call(changes[:modified],changes[:added],changes[:removed])
      end
    end

    # Initialize the @paths double levels Hash with all existing paths.
    #
    def init_paths
      @paths = Hash.new { |h,k| h[k] = {} }
      all_existing_paths { |path| insert_path(path) }
    end

    # Detect changes diff in a directory.
    #
    # @param [String] directory the path to diff
    # @return [Hash<Array>] the file changes
    #
    def diff(directory = @directory)
      @changes = { :modified => [], :added => [], :removed => [] }
      detect_modifications_and_removals(directory)
      detect_additions(directory)
      @changes
    end

  private

    # Research all existing paths (directories & files) filtered and without ignored directories paths.
    #
    # @yield [path] the existing path
    #
    def all_existing_paths
      Find.find(@directory) do |path|
        if File.directory?(path)
          if @ignored_paths.any? { |ignored_path| path =~ /#{ignored_path}$/ }
            Find.prune # Don't look any further into this directory.
          else
            yield(path)
          end
        elsif @file_filters.empty? || @file_filters.any? { |file_filter| path =~ file_filter }
          yield(path)
        end
      end
    end

    # Insert a path with its File.stat in @paths.
    #
    # @param [String] path the path to insert in @paths.
    #
    def insert_path(path)
      @paths[File.dirname(path)][File.basename(path)] = File.stat(path)
    end

    # Detect modifications and removals recursivly in a directory.
    #
    # @param [String] directory the path to analyze
    #
    def detect_modifications_and_removals(directory)
      @paths[directory].each do |basename, stat|
        path = File.join(directory, basename)

        if stat.directory?
          detect_modifications_and_removals(path)
          @paths[directory].delete(basename) unless File.directory?(path)
        else
          if File.exist?(path)
            new_stat = File.stat(path)
            if stat.mtime != new_stat.mtime
              @changes[:modified] << relative_path(path)
              @paths[directory][basename] = new_stat
            end
          else
            @paths[directory].delete(basename)
            @changes[:removed] << relative_path(path)
          end
        end
      end
    end

    # Detect additions in a directory.
    #
    # @param [String] directory the path to analyze
    #
    def detect_additions(directory)
      all_existing_paths do |path|
        next if @paths[File.dirname(path)][File.basename(path)]

        @changes[:added] << relative_path(path) if File.file?(path)
        insert_path(path)
      end
    end

    # Convert absolute path to a path relative to the listener directory (by default).
    #
    # @param [String] path the path to convert
    # @param [String] directory the directoy path to relative from
    # @return [String] the relative converted path
    #
    def relative_path(path, directory = @directory)
      base_dir = directory.sub(/\/$/, '')
      path.sub(%r(^#{base_dir}/), '')
    end

  end
end
