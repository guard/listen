require 'listen/record/entry'
require 'listen/record/symlink_detector'

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
      Celluloid::Logger.warn "build crashed: #{$ERROR_INFO.inspect}"
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

    # TODO: test with a file name given
    # TODO: test other permissions
    # TODO: test with mixed encoding
    def _fast_build(root)
      symlink_detector = SymlinkDetector.new
      @paths[root] = _auto_hash
      remaining = Queue.new
      remaining << Entry.new(root, nil, nil)
      _fast_build_dir(remaining, symlink_detector) until remaining.empty?
    end

    def _fast_build_dir(remaining, symlink_detector)
      entry = remaining.pop
      children = entry.children # NOTE: children() implicitly tests if dir
      symlink_detector.verify_unwatched!(entry)
      children.each { |child| remaining << child }
      add_dir(entry.root, entry.record_dir_key)
    rescue Errno::ENOTDIR
      _fast_try_file(entry)
    rescue SystemCallError, SymlinkDetector::Error
      _fast_unset_path(entry.root, entry.relative, entry.name)
    end

    def _fast_try_file(entry)
      _fast_update_file(entry.root, entry.relative, entry.name, entry.meta)
    rescue SystemCallError
      _fast_unset_path(entry.root, entry.relative, entry.name)
    end
  end
end
