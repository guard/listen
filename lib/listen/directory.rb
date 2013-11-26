module Listen
  class Directory
    attr_accessor :listener, :path, :options

    def initialize(listener, path, options = {})
      @listener    = listener
      @path    = path
      @options = options
    end

    def scan
      _update_record
      _all_entries.each do |entry_path, data|
        case data[:type]
        when 'File'
          _async_change(entry_path, options.merge(type: 'File'))
        when 'Dir'
          _async_change(entry_path, options.merge(type: 'Dir')) if _recursive_scan?(entry_path)
        end
      end
    end

    private

    def _update_record
      if ::Dir.exists?(path)
        _record.async.set_path(path, { type: 'Dir'})
      else
        _record.async.unset_path(path)
      end
    end

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
      listener.registry[:record]
    end

    def _change_pool
      listener.registry[:change_pool]
    end

    def _recursive_scan?(path)
      !::Dir.exists?(path) || options[:recursive]
    end

    def _async_change(entry_path, options)
      entry_path = path.join(entry_path)
      _change_pool.async.change(entry_path, options)
    end
  end
end
