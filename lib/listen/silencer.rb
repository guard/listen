module Listen
  class Silencer
    include Celluloid

    # The default list of directories that get ignored.
    DEFAULT_IGNORED_DIRECTORIES = %w[.bundle .git .hg .rbx .svn bundle log tmp vendor/ruby vendor/bundle]

    # The default list of files that get ignored.
    DEFAULT_IGNORED_EXTENSIONS  = %w[.DS_Store .tmp]

    attr_accessor :listener, :only_patterns, :ignore_patterns

    def initialize(listener)
      @listener = listener
      _init_only_patterns
      _init_ignore_patterns
    end

    def silenced?(path, type = 'Unknown')
      silenced = false

      if only_patterns && type == 'File'
        silenced = !only_patterns.any? { |pattern| _relative_path(path) =~ pattern }
      end

      silenced ||= ignore_patterns.any? { |pattern| _relative_path(path) =~ pattern }
    end

    private

    def _init_only_patterns
      if listener.options[:only]
        @only_patterns = Array(listener.options[:only])
      end
    end

    def _init_ignore_patterns
      @ignore_patterns = []
      @ignore_patterns << _default_ignore_patterns unless listener.options[:ignore!]
      @ignore_patterns << listener.options[:ignore] << listener.options[:ignore!]
      @ignore_patterns.compact!
      @ignore_patterns.flatten!
    end

    def _default_ignore_patterns
      [_default_ignored_directories_patterns, _default_ignored_extensions_patterns]
    end

    def _default_ignored_directories_patterns
      ignored_directories = DEFAULT_IGNORED_DIRECTORIES.map { |d| Regexp.escape(d) }
      %r{^(?:#{ignored_directories.join('|')})(/|$)}
    end

    def _default_ignored_extensions_patterns
      ignored_extensions = DEFAULT_IGNORED_EXTENSIONS.map { |e| Regexp.escape(e) }
      %r{(?:#{ignored_extensions.join('|')})$}
    end

    def _relative_path(path)
      relative_paths = listener.directories.map { |dir| path.relative_path_from(dir).to_s }
      relative_paths.detect { |path| !path.start_with?('../') }
    end
  end
end
