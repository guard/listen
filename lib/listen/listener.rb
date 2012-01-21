module Listen
  class Listener

    def initialize(*args, &block)
      @directory = args.first
      @paths     = Hash.new {|h,k| h[k] = {} }
      @block     = block
      init_paths
    end

    # Start the listener.
    #
    def start
      # TODO
    end

    # Detect changes diff in a directory.
    #
    # @param [String] directory the path to diff
    # @return {Hash<Array>} the file changes
    #
    def diff(directory = @directory)
      @changes = { :modified => [], :added => [], :removed => [] }
      detect_modifications_and_removals(directory)
      detect_additions(directory)
      @changes
    end

  private

    # Initialize the @paths double levels Hash at listener initialization.
    #
    def init_paths
      Dir.glob("#{@directory}/**/*", File::FNM_DOTMATCH).each do |path|
        insert_path(path)
      end
    end

    # Insert a path with its File.stats in @paths.
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
          @paths[directory].delete(basename) unless Dir.exist?(path)
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
      Dir.glob("#{directory}/**/*", File::FNM_DOTMATCH) do |path|
        next if path =~ /\/\./
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
      base_dir = @directory.sub(/\/$/, '')
      path.sub(%r(^#{base_dir}/), '')
    end

  end
end
