module Listen
  class Silencer

    # Adds ignoring patterns to the listener.
    #
    # @param (see Listen::DirectoryRecord#ignore)
    #
    # @return [Listen::Listener] the listener
    #
    # @see Listen::DirectoryRecord#ignore
    #
    def ignore(*regexps)
      directories_records.each { |r| r.ignore(*regexps) }
      self
    end

    # Replaces ignoring patterns in the listener.
    #
    # @param (see Listen::DirectoryRecord#ignore!)
    #
    # @return [Listen::Listener] the listener
    #
    # @see Listen::DirectoryRecord#ignore!
    #
    def ignore!(*regexps)
      directories_records.each { |r| r.ignore!(*regexps) }
      self
    end

    # Adds filtering patterns to the listener.
    #
    # @param (see Listen::DirectoryRecord#filter)
    #
    # @return [Listen::Listener] the listener
    #
    # @see Listen::DirectoryRecord#filter
    #
    def filter(*regexps)
      directories_records.each { |r| r.filter(*regexps) }
      self
    end

    # Replaces filtering patterns in the listener.
    #
    # @param (see Listen::DirectoryRecord#filter!)
    #
    # @return [Listen::Listener] the listener
    #
    # @see Listen::DirectoryRecord#filter!
    #
    def filter!(*regexps)
      directories_records.each { |r| r.filter!(*regexps) }
      self
    end

    # The default list of directories that get ignored by the listener.
    DEFAULT_IGNORED_DIRECTORIES = %w[.rbx .bundle .git .svn log tmp vendor]

    # The default list of files that get ignored by the listener.
    DEFAULT_IGNORED_EXTENSIONS  = %w[.DS_Store]

    # Class methods
    #
    class << self

      # Creates the ignoring patterns from the default ignored
      # directories and extensions. It memoizes the generated patterns
      # to avoid unnecessary computation.
      #
      def generate_default_ignoring_patterns
        @@default_ignoring_patterns ||= Array.new.tap do |default_patterns|
          # Add directories
          ignored_directories = DEFAULT_IGNORED_DIRECTORIES.map { |d| Regexp.escape(d) }
          default_patterns << %r{^(?:#{ignored_directories.join('|')})/}

          # Add extensions
          ignored_extensions = DEFAULT_IGNORED_EXTENSIONS.map { |e| Regexp.escape(e) }
          default_patterns << %r{(?:#{ignored_extensions.join('|')})$}
        end
      end
    end

    # Initializes a directory record.
    #
    # @option [String] directory the directory to keep track of
    #
    def initialize(directory)
      @ignoring_patterns, @filtering_patterns = Set.new, Set.new

      @ignoring_patterns.merge(DirectoryRecord.generate_default_ignoring_patterns)
    end

    # Returns the ignoring patterns in the record to know
    # which paths should be ignored.
    #
    # @return [Array<Regexp>] the ignoring patterns
    #
    def ignoring_patterns
      @ignoring_patterns.to_a
    end

    # Returns the filtering patterns in the record to know
    # which paths should be stored.
    #
    # @return [Array<Regexp>] the filtering patterns
    #
    def filtering_patterns
      @filtering_patterns.to_a
    end

    # Adds ignoring patterns to the record.
    #
    # @example Ignore some paths
    #   ignore %r{^ignored/path/}, /man/
    #
    # @param [Regexp] regexps a list of patterns for ignoring paths
    #
    def ignore(*regexps)
      @ignoring_patterns.merge(regexps).reject! { |r| r.nil? }
    end

    # Replaces ignoring patterns in the record.
    #
    # @example Ignore only these paths
    #   ignore! %r{^ignored/path/}, /man/
    #
    # @param [Regexp] regexps a list of patterns for ignoring paths
    #
    def ignore!(*regexps)
      @ignoring_patterns.replace(regexps).reject! { |r| r.nil? }
    end

    # Adds filtering patterns to the record.
    #
    # @example Filter some files
    #   filter /\.txt$/, /.*\.zip/
    #
    # @param [Regexp] regexps a list of patterns for filtering files
    #
    def filter(*regexps)
      @filtering_patterns.merge(regexps).reject! { |r| r.nil? }
    end

    # Replaces filtering patterns in the record.
    #
    # @example Filter only these files
    #   filter! /\.txt$/, /.*\.zip/
    #
    # @param [Regexp] regexps a list of patterns for filtering files
    #
    def filter!(*regexps)
      @filtering_patterns.replace(regexps).reject! { |r| r.nil? }
    end

    # Returns whether a path should be ignored or not.
    #
    # @param [String] path the path to test
    #
    # @return [Boolean]
    #
    def ignored?(path)
      path = relative_to_base(path)
      @ignoring_patterns.any? { |pattern| pattern =~ path }
    end

    # Returns whether a path should be filtered or not.
    #
    # @param [String] path the path to test
    #
    # @return [Boolean]
    #
    def filtered?(path)
      # When no filtering patterns are set, ALL files are stored.
      return true if @filtering_patterns.empty?

      path = relative_to_base(path)
      @filtering_patterns.any? { |pattern| pattern =~ path }
    end


  end
end
