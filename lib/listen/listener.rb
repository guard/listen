require 'find'
require 'listen/adapter'
require 'listen/adapters/darwin'
require 'listen/adapters/linux'
require 'listen/adapters/polling'

module Listen
  class Listener
    attr_accessor :directory, :ignored_paths, :file_filters, :paths, :adapter

    # Default paths that gets ignored by the listener
    DEFAULT_IGNORED_PATHS = %w[.bundle .git .DS_Store log tmp vendor]

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
    # @param [Array] directories the list of directories to diff
    #
    def on_change(directories)
      changes = diff(directories)
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
    # @param [Array] directories the list of directories to diff
    # @param [Hash] options
    # @option options [Boolean] recursive scan all sub-direcoties recursively (true when polling)
    # @return [Hash<Array>] the file changes
    #
    def diff(directories, options = {})
      @changes = { :modified => [], :added => [], :removed => [] }
      options[:recursive] = @adapter.is_a?(Listen::Adapters::Polling) if options[:recursive].nil?
      directories = directories.sort_by { |el| el.length }.reverse # diff sub-dir first
      directories.each do |directory|
        detect_modifications_and_removals(directory, options)
        detect_additions(directory, options)
      end
      @changes
    end

  private

    # Research all existing paths (directories & files) filtered and without ignored directories paths.
    #
    # @yield [path] the existing path
    #
    def all_existing_paths
      Find.find(@directory) do |path|
        next if @directory == path

        if File.directory?(path)
          if ignored_path?(path)
            Find.prune # Don't look any further into this directory.
          else
            yield(path)
          end
        elsif !ignored_path?(path) && filtered_file?(path)
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

    # Find is a path exists in @paths.
    #
    # @param [String] path the path to find in @paths.
    # @return [Boolean]
    #
    def existing_path?(path)
      @paths[File.dirname(path)][File.basename(path)] != nil
    end

    # Detect modifications and removals recursivly in a directory.
    #
    # @param [String] directory the path to analyze
    # @param [Hash] options
    # @option options [Boolean] recursive scan all sub-direcoties recursively (when polling)
    #
    def detect_modifications_and_removals(directory, options = {})
      @paths[directory].each do |basename, stat|
        path = File.join(directory, basename)

        if stat.directory?
          if File.directory?(path)
            detect_modifications_and_removals(path, options) if options[:recursive]
          else
            detect_modifications_and_removals(path, :recursive => true)
            @paths[directory].delete(basename)
            @paths.delete("#{directory}/#{basename}")
          end
        else # File
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
    # @param [Hash] options
    # @option options [Boolean] recursive scan all sub-direcoties recursively (when polling)
    #
    def detect_additions(directory, options = {})
      Find.find(directory) do |path|
        next if @directory == path

        if File.directory?(path)
          if directory != path && (ignored_path?(path) || (!options[:recursive] && existing_path?(path)))
            Find.prune # Don't look any further into this directory.
          else
            insert_path(path)
          end
        elsif !existing_path?(path) && !ignored_path?(path) && filtered_file?(path)
          @changes[:added] << relative_path(path) if File.file?(path)
          insert_path(path)
        end
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

    # Test if a path should be ignored or not.
    #
    # @param [String] path the path to test.
    # @return [Boolean]
    #
    def ignored_path?(path)
      @ignored_paths.any? { |ignored_path| path =~ /#{ignored_path}$/ }
    end

    # Test if a file path should be filtered or not.
    #
    # @param [String] path the file path to test.
    # @return [Boolean]
    #
    def filtered_file?(path)
      @file_filters.empty? || @file_filters.any? { |file_filter| path =~ file_filter }
    end

  end
end
