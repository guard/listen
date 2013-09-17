module Listen
  class Silencer
    include Celluloid

    # The default list of directories that get ignored.
    DEFAULT_IGNORED_DIRECTORIES = %w[.bundle .git .hg .rbx .svn bundle log tmp vendor/ruby]

    # The default list of files that get ignored.
    DEFAULT_IGNORED_EXTENSIONS  = %w[.DS_Store]

    attr_accessor :options, :patterns

    def initialize(options = {})
      @options = options
      _init_patterns
    end

    def silenced?(path)
      patterns.any? { |pattern| path.to_s =~ pattern }
    end

    private

    def _init_patterns
      @patterns = []
      @patterns << _default_patterns unless options[:ignore!]
      @patterns << options[:ignore] << options[:ignore!]
      @patterns.compact!
      @patterns.flatten!
    end

    def _default_patterns
      [_default_ignored_directories_patterns, _default_ignored_extensions_patterns]
    end

    def _default_ignored_directories_patterns
      ignored_directories = DEFAULT_IGNORED_DIRECTORIES.map { |d| Regexp.escape(d) }
      %r{(?:#{ignored_directories.join('|')})}
    end

    def _default_ignored_extensions_patterns
      ignored_extensions = DEFAULT_IGNORED_EXTENSIONS.map { |e| Regexp.escape(e) }
      %r{(?:#{ignored_extensions.join('|')})$}
    end
  end
end
