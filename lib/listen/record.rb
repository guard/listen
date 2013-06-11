module Listen
  class Record
    include Celluloid

    attr_accessor :paths

    def initialize
      @paths = Hash.new { |h, k| h[k] = Hash.new }
    end

    def set_path(path, data)
      @paths[::File.dirname(path)][::File.basename(path)] = data
    end

    def unset_path(path)
      @paths[::File.dirname(path)].delete(::File.basename(path))
    end

    def file_data(path)
      @paths[::File.dirname(path)][::File.basename(path)]
    end

    def dir_entries(path)
      @paths[path]
    end
  end
end
