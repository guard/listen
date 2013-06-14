module Listen
  class Directory
    attr_accessor :path, :options

    def initialize(path, options = {})
      @path    = path
      @options = options
    end

    def scan
      _all_entries.each do |entry_path, data|
        case data[:type]
        when 'File' then _async_change(entry_path, type: 'File')
        when 'Dir'
          _async_change(entry_path, options.merge(type: 'Dir')) if options[:recursive]
        end
      end
    end

    private

    def _all_entries
      _record_entries.merge(_entries)
    end

    def _entries
      return {} unless ::Dir.exists?(path)
      entries = ::Dir.entries(path) - %w[. ..]
      entries = entries.map { |entry| [entry, type: _entry_type(entry)] }
      Hash[*entries.flatten]
    end

    def _entry_type(entry_path)
      entry_path = path.join(entry_path)
      if entry_path.file?
        'File'
      elsif entry_path.directory?
        'Dir'
      end
    end

    def _record_entries
      future = _record.future.dir_entries(path)
      future.value
    end

    def _record
      Celluloid::Actor[:record]
    end

    def _change_pool
      Celluloid::Actor[:change_pool]
    end

    def _async_change(entry_path, options)
      entry_path = path.join(entry_path)
      _change_pool.async.change(entry_path, options)
    end
  end
end
