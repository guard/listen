module Listen
  class Record
    include Celluloid

    attr_accessor :paths

    def initialize
      @paths = _init_paths
    end

    def set_path(path, data)
      @paths[::File.dirname(path)][::File.basename(path)] = file_data(path).merge(data)
    end

    def unset_path(path)
      @paths[::File.dirname(path)].delete(::File.basename(path))
    end

    def file_data(path)
      @paths[::File.dirname(path)][::File.basename(path)] || {}
    end

    def dir_entries(path)
      @paths[path]
    end

    # TODO test
    def build(directories)
      @paths = _init_paths
      directories.each do |path|
        Actor[:change_pool].async.change(path, type: 'Dir', recursive: true, silence: true)
      end
    end

    private

    def _init_paths
      Hash.new { |h, k| h[k] = Hash.new }
    end
  end
end
