module Listen
  class Record
    include Celluloid

    # TODO: one Record object per watched directory?

    # TODO: deprecate
    attr_accessor :paths, :listener

    def initialize(listener)
      @listener = listener
      @paths    = _auto_hash
      @condition = nil
      @timer = nil
    end

    def add_dir(dir, rel_path)
      return if [nil, '', '.'].include? rel_path
      @paths[dir.to_s][rel_path] ||= {}
    end

    def update_file(dir, rel_path, data)
      dirname, basename = Pathname(rel_path).split.map(&:to_s)
      if [nil, '', '.'].include? dirname
        new_data = (@paths[dir.to_s][basename] || {}).merge(data)
        @paths[dir.to_s][basename] = new_data
      else
        @paths[dir.to_s][dirname] ||= {}
        new_data = (@paths[dir.to_s][dirname][basename] || {}).merge(data)
        @paths[dir.to_s][dirname][basename] = new_data
      end
    end

    def unset_path(dir, rel_path)
      dirname, basename = Pathname(rel_path).split.map(&:to_s)
      # this may need to be reworked to properly remove
      # entries from a tree, without adding non-existing dirs to the record
      @paths[dir.to_s][dirname] ||= {}
      @paths[dir.to_s][dirname].delete(basename)
    end

    def file_data(dir, rel_path)
      dirname, basename = Pathname(rel_path).split.map(&:to_s)
      if [nil, '', '.'].include? dirname
        @paths[dir.to_s][basename] ||= {}
        @paths[dir.to_s][basename].dup
      else
        @paths[dir.to_s][dirname] ||= {}
        @paths[dir.to_s][dirname][basename] ||= {}
        @paths[dir.to_s][dirname][basename].dup
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
      @condition = Celluloid::Condition.new
      @paths = _auto_hash

      # TODO: refactor this out (1 Record = 1 watched dir)
      listener.directories.each do |path|
        @paths[path.to_s] = _auto_hash

        options = { recursive: true, silence: true, build: true }
        listener.async(:change_pool).change(:dir, path, '.', options)
      end

      @timer = after(1) { @condition.signal }
      @condition.wait
      @timer = nil
    rescue
      Celluloid.logger.warn "build crashed: #{$!.inspect}"
      raise
    end

    def still_building!
      timer = @timer
      timer.reset if timer
    end

    private

    def _auto_hash
      Hash.new { |h, k| h[k] = Hash.new }
    end
  end
end
