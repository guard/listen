module Listen
  class Record
    include Celluloid

    # TODO: one Record object per watched directory?

    # TODO: deprecate
    attr_accessor :paths, :listener

    def initialize(listener)
      @listener = listener
      @paths    = _auto_hash
    end

    def add_dir(dir, rel_path)
      return if [nil, '', '.'].include? rel_path
      @paths[dir.to_s][rel_path] ||= {}
    end

    def update_file(dir, rel_path, data)
      dirname, basename = Pathname(rel_path).split.map(&:to_s)
      _fast_update_file(dir, dirname, basename, data)
    end

    def unset_path(dir, rel_path)
      dirname, basename = Pathname(rel_path).split.map(&:to_s)
      _fast_unset_path(dir, dirname, basename)
    end

    def file_data(dir, rel_path)
      root = @paths[dir.to_s]
      dirname, basename = Pathname(rel_path).split.map(&:to_s)
      if [nil, '', '.'].include? dirname
        root[basename] ||= {}
        root[basename].dup
      else
        root[dirname] ||= {}
        root[dirname][basename] ||= {}
        root[dirname][basename].dup
      end
    end

    def dir_entries(dir, rel_path)
      tree = if [nil, '', '.'].include? rel_path.to_s
               @paths[dir.to_s]
             else
               @paths[dir.to_s][rel_path.to_s] ||= _auto_hash
               @paths[dir.to_s][rel_path.to_s]
             end

      result = {}
      tree.each do |key, values|
        # only get data for file entries
        result[key] = values.key?(:mtime) ? values : {}
      end
      result
    end

    def build
      start = Time.now.to_f
      @paths = _auto_hash

      # TODO: refactor this out (1 Record = 1 watched dir)
      listener.directories.each do |directory|
        _fast_build(directory.to_s)
      end

      Celluloid::Logger.info "Record.build(): #{Time.now.to_f - start} seconds"
    rescue
      Celluloid::Logger.warn "build crashed: #{$!.inspect}"
      raise
    end

    private

    def _auto_hash
      Hash.new { |h, k| h[k] = Hash.new }
    end

    def _fast_update_file(dir, dirname, basename, data)
      root = @paths[dir.to_s]
      if [nil, '', '.'].include? dirname
        root[basename] = (root[basename] || {}).merge(data)
      else
        root[dirname] ||= {}
        root[dirname][basename] = (root[dirname][basename] || {}).merge(data)
      end
    end

    def _fast_unset_path(dir, dirname, basename)
      root = @paths[dir.to_s]
      # this may need to be reworked to properly remove
      # entries from a tree, without adding non-existing dirs to the record
      if [nil, '', '.'].include? dirname
        return unless root.key?(basename)
        root.delete(basename)
      else
        return unless root.key?(dirname)
        root[dirname].delete(basename)
      end
    end

    def _fast_build(root)
      @paths[root] = _auto_hash
      left = Queue.new
      left << '.'

      while !left.empty?
        dirname = left.pop
        add_dir(root, dirname)

        path = ::File.join(root, dirname)
        current = Dir.entries(path.to_s) - %w(. ..)

        current.each do |entry|
          full_path = ::File.join(path, entry)

          if Dir.exist?(full_path)
            left << (dirname == '.' ? entry : ::File.join(dirname, entry))
          else
            begin
              lstat = ::File.lstat(full_path)
              data = { mtime: lstat.mtime.to_f, mode: lstat.mode }
              _fast_update_file(root, dirname, entry, data)
            rescue SystemCallError
              _fast_unset_path(root, dirname, entry)
            end
          end
        end
      end
    end
  end
end
