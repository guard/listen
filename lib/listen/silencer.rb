module Listen
  class Silencer
    include Celluloid

    # The default list of directories that get ignored.
    DEFAULT_IGNORED_DIRECTORIES = %r{^(?:
      \.git
      | \.svn
      | \.hg
      | \.rbx
      | \.bundle
      | bundle
      | vendor/bundle
      | log
      | tmp
      |vendor/ruby
    )(/|$)}x

    # The default list of files that get ignored.
    DEFAULT_IGNORED_EXTENSIONS  = %r{(?:
      # Kate's tmp/swp files
      \..*\d+\.new
      | \.kate-swp

      # Gedit tmp files
      | \.goutputstream-.{6}

      # other files
      | \.DS_Store
      | \.tmp
      | ~
    )$}x

    attr_accessor :listener, :only_patterns, :ignore_patterns

    def initialize(listener)
      @listener = listener
      _init_only_patterns
      _init_ignore_patterns
    end

    def silenced?(path, type = 'Unknown')
      silenced = false

      relative_path = _relative_path(path)

      if only_patterns && type == 'File'
        silenced = !only_patterns.any? { |pattern| relative_path =~ pattern }
      end

      silenced || ignore_patterns.any? { |pattern| relative_path =~ pattern }
    end

    def match(args)
      path, type = args.first
      silenced?(path, type)
    end

    private

    def _init_only_patterns
      if listener.options[:only]
        @only_patterns = Array(listener.options[:only])
      end
    end

    def _init_ignore_patterns
      options = listener.options

      patterns = []
      unless options[:ignore!]
        patterns << DEFAULT_IGNORED_DIRECTORIES
        patterns << DEFAULT_IGNORED_EXTENSIONS
      end

      patterns << options[:ignore]
      patterns << options[:ignore!]

      patterns.compact!
      patterns.flatten!

      @ignore_patterns = patterns
    end

    def _relative_path(path)
      relative_paths = listener.directories.map do |dir|
        begin
          path.relative_path_from(dir).to_s
        rescue ArgumentError
          # Windows raises errors across drives, e.g. when 'C:/' and 'E:/dir'
          # So, here's a Dirty hack to fool the detect() below..
          '../'
        end
      end
      relative_paths.detect { |rel_path| !rel_path.start_with?('../') }
    end
  end
end
