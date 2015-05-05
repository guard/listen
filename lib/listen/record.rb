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
      @paths = {}
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
      dirname = '.' if [nil, '', '.'].include? dirname
      fail "directory not watched: #{dir}" unless root

      root[dirname] ||= {}
      root[dirname][basename] ||= {}
      root[dirname][basename].dup
    end

    def dir_entries(dir, rel_path)
      rel_path = '.' if [nil, '', '.'].include? rel_path.to_s
      @paths[dir.to_s][rel_path.to_s] ||= {}
    end

    def build
      start = Time.now.to_f
      @paths = {}

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

    # TODO: refactor/refactor out
    def add_dir(dir, rel_path)
      rel_path = '.' if [nil, '', '.'].include? rel_path
      dirname, basename = Pathname(rel_path).split.map(&:to_s)
      basename = '.' if [nil, '', '.'].include? basename
      root = (@paths[dir.to_s] ||= {})
      if [nil, '', '.'].include?(dirname)
        entries = (root['.'] || {})
        entries.merge!(basename => {}) if basename != '.'
        root['.'] = entries
      else
        root[rel_path] ||= {}
      end
    end

    def _fast_update_file(dir, dirname, basename, data)
      root = @paths[dir.to_s]
      dirname = '.' if [nil, '', '.'].include? dirname

      internal_dirname, internal_key = ::File.split(dirname.to_s)
      if internal_dirname == '.' && internal_key != '.'
        root[internal_dirname] ||= {}
        root[internal_dirname][internal_key] ||= {}
      end

      root[dirname] ||= {}
      root[dirname][basename] = (root[dirname][basename] || {}).merge(data)
    end

    def _fast_unset_path(dir, dirname, basename)
      root = @paths[dir.to_s]
      # this may need to be reworked to properly remove
      # entries from a tree, without adding non-existing dirs to the record
      dirname = '.' if [nil, '', '.'].include? dirname
      return unless root.key?(dirname)
      root[dirname].delete(basename)
    end

    # TODO: test with a file name given
    # TODO: test other permissions
    # TODO: test with mixed encoding
    def _fast_build(root)
      symlink_detector = SymlinkDetector.new
      @paths[root] = {}
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
