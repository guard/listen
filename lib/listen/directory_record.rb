require 'set'
require 'find'
require 'pathname'
require 'digest/sha1'

module Listen

  # The directory record stores information about
  # a directory and keeps track of changes to
  # the structure of its childs.
  #
  class DirectoryRecord
    attr_reader :directory, :paths, :sha1_checksums

    # Default paths' beginnings that doesn't get stored in the record
    DEFAULT_IGNORED_PATHS = %w[.bundle .git .DS_Store log tmp vendor]

    # Initializes a directory record.
    #
    # @option [String] directory the directory to keep track of
    #
    def initialize(directory)
      @directory = directory
      raise ArgumentError, "The path '#{directory}' is not a directory!" unless File.directory?(@directory)

      @ignored_paths  = Set.new(DEFAULT_IGNORED_PATHS)
      @filters        = Set.new
      @sha1_checksums = Hash.new
    end

    # Returns the ignored paths in the record
    #
    # @return [Array<String>] the ignored paths
    #
    def ignored_paths
      @ignored_paths.to_a
    end

    # Returns the filters used in the record to know
    # which paths should be stored.
    #
    # @return [Array<String>] the used filters
    #
    def filters
      @filters.to_a
    end

    # Adds ignored path to the record.
    #
    # @example Ignore some paths
    #   ignore ".git", ".svn"
    #
    # @param [String, Array<String>] paths a path or a list of paths to ignore
    #
    def ignore(*paths)
      @ignored_paths.merge(paths)
    end

    # Adds file filters to the listener.
    #
    # @example Filter some files
    #   ignore /\.txt$/, /.*\.zip/
    #
    # @param [Array<Regexp>] regexps a list of regexps file filters
    #
    # @return [Listen::Listener] the listener itself
    #
    def filter(*regexps)
      @filters.merge(regexps)
    end

    # Returns whether a path should be ignored or not.
    #
    # @param [String] path the path to test.
    #
    # @return [Boolean]
    #
    def ignored?(path)
      @ignored_paths.any? { |ignored_path| path =~ /#{ignored_path}$/ }
    end

    # Returns whether a path should be filtered or not.
    #
    # @param [String] path the path to test.
    #
    # @return [Boolean]
    #
    def filtered?(path)
      @filters.empty? || @filters.any? { |filter| path =~ filter }
    end

    # Finds the paths that should be stored and adds them
    # to the paths' hash.
    #
    def build
      @paths = Hash.new { |h, k| h[k] = Hash.new }
      important_paths { |path| insert_path(path) }
      @updated_at = Time.now.to_i
    end

    # Detects changes in the passed directories, updates
    # the record with the new changes and returns the changes
    #
    # @param [Array] directories the list of directories scan for changes
    # @param [Hash] options
    # @option options [Boolean] recursive scan all sub-directories recursively
    # @option options [Boolean] relative_paths whether or not to use relative paths for changes
    #
    # @return [Hash<Array>] the changes
    #
    def fetch_changes(directories, options = {})
      @changes    = { :modified => [], :added => [], :removed => [] }
      directories = directories.sort_by { |el| el.length }.reverse # diff sub-dir first
      directories.each do |directory|
        next unless directory[@directory] # Path is or inside directory
        detect_modifications_and_removals(directory, options)
        detect_additions(directory, options)
      end
      @updated_at = Time.now.to_i
      @changes
    end

    private

    # Detects modifications and removals recursively in a directory.
    #
    # @note Modifications detection begins by checking the modification time (mtime)
    #   of files and then by checking content changes (using SHA1-checksum)
    #   when the mtime of files is not changed.
    #
    # @param [String] directory the path to analyze
    # @param [Hash] options
    # @option options [Boolean] recursive scan all sub-directories recursively
    # @option options [Boolean] relative_paths whether or not to use relative paths for changes
    #
    def detect_modifications_and_removals(directory, options = {})
      @paths[directory].each do |basename, type|
        path = File.join(directory, basename)

        case type
        when 'Dir'
          if File.directory?(path)
            detect_modifications_and_removals(path, options) if options[:recursive]
          else
            detect_modifications_and_removals(path, { :recursive => true }.merge(options))
            @paths[directory].delete(basename)
            @paths.delete("#{directory}/#{basename}")
          end
        when 'File'
          if File.exist?(path)
            new_mtime = File.mtime(path).to_i
            if @updated_at < new_mtime || (@updated_at == new_mtime && content_modified?(path))
              @changes[:modified] << (options[:relative_paths] ? relative_to_base(path) : path)
            end
          else
            @paths[directory].delete(basename)
            @sha1_checksums.delete(path)
            @changes[:removed] << (options[:relative_paths] ? relative_to_base(path) : path)
          end
        end
      end
    end

    # Detects additions in a directory.
    #
    # @param [String] directory the path to analyze
    # @param [Hash] options
    # @option options [Boolean] recursive scan all sub-directories recursively
    # @option options [Boolean] relative_paths whether or not to use relative paths for changes
    #
    def detect_additions(directory, options = {})
      # Don't process removed directories
      return unless File.exist?(directory)

      Find.find(directory) do |path|
        next if path == @directory

        if File.directory?(path)
          if ignored?(path) || (directory != path && (!options[:recursive] && existing_path?(path)))
            Find.prune # Don't look any further into this directory.
          else
            insert_path(path)
          end
        elsif !ignored?(path) && filtered?(path) && !existing_path?(path)
          if File.file?(path)
            @changes[:added] << (options[:relative_paths] ? relative_to_base(path) : path)
          end
          insert_path(path)
        end
      end
    end

    # Returns whether or not a file's content has been modified by
    # comparing the SHA1-checksum to a stored one.
    #
    # @param [String] path the file path
    #
    def content_modified?(path)
      sha1_checksum = Digest::SHA1.file(path).to_s
      if @sha1_checksums[path] != sha1_checksum
        @sha1_checksums[path] = sha1_checksum
        true
      else
        false
      end
    end

    # Traverses the base directory looking for paths that should
    # be stored; thus paths that are filters or not ignored.
    #
    # @yield [path] an important path
    #
    def important_paths
      Find.find(@directory) do |path|
        next if path == @directory

        if File.directory?(path)
          if ignored?(path)
            Find.prune # Don't look any further into this directory.
          else
            yield(path)
          end
        elsif !ignored?(path) && filtered?(path)
          yield(path)
        end
      end
    end

    # Inserts a path with its type (Dir or File) in paths hash.
    #
    # @param [String] path the path to insert in @paths.
    #
    def insert_path(path)
      @paths[File.dirname(path)][File.basename(path)] = File.directory?(path) ? 'Dir' : 'File'
    end

    # Returns whether or not a path exists in the paths hash.
    #
    # @param [String] path the path to check
    #
    # @return [Boolean]
    #
    def existing_path?(path)
      @paths[File.dirname(path)][File.basename(path)] != nil
    end

    # Converts an absolute path to a path that's relative to the base directory.
    #
    # @param [String] path the path to convert
    #
    # @return [String] the relative path
    #
    def relative_to_base(path)
      path.sub(%r(^#{@directory}/?/), '')
    end
  end
end
