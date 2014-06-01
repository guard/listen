module Listen
  class Record
    include Celluloid

    # TODO: deprecate
    attr_accessor :paths, :listener

    def initialize(listener)
      @listener = listener
      @paths    = _init_paths
    end

    def set_path(type, path, data = {})
      new_data = file_data(path).merge(data).merge(type: type)
      @paths[::File.dirname(path)][::File.basename(path)] = new_data
    end

    def unset_path(path)
      @paths[::File.dirname(path)].delete(::File.basename(path))
    end

    def file_data(path)
      @paths[::File.dirname(path)][::File.basename(path)] || {}
    end

    def dir_entries(path)
      @paths[path.to_s].dup
    end

    def build
      @last_build_at = Time.now
      @paths = _init_paths
      listener.directories.each do |path|
        options = { recursive: true, silence: true, build: true }
        listener.sync(:change_pool).change(:dir, path, options)
      end
      sleep 0.01 until @last_build_at + 0.1 < Time.now
    rescue
      Celluloid.logger.warn "build crashed: #{$!.inspect}"
      raise
    end

    def still_building!
      @last_build_at = Time.now
    end

    private

    def _init_paths
      Hash.new { |h, k| h[k] = Hash.new }
    end
  end
end
