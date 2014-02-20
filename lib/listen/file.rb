module Listen
  class File
    attr_accessor :listener, :path, :data, :md5

    def initialize(listener, path)
      @listener = listener
      @path = path
      @data = { type: 'File' }
    end

    def change
      if _existing_path? && _modified?
        _set_record_data
        :modified
      elsif _new_path?
        _set_record_data
        :added
      elsif _removed_path?
        _unset_record_data
        :removed
      end
    end

    private

    def _new_path?
      _exist? && !_record_data?
    end

    def _existing_path?
      _exist? && _record_data?
    end

    def _removed_path?
      !_exist?
    end

    def _record_data?
      !_record_data.empty?
    end

    def _exist?
      @exist ||= ::File.exist?(path)
    end

    def _modified?
      _mtime > _record_data[:mtime] || _mode_modified? || _content_modified?
    end

    def _mode_modified?
      _mode != _record_data[:mode]
    end

    # Only useful on Darwin because of the file mtime second precision.
    # Only check if in the same seconds (mtime == current time).
    # MD5 is eager loaded, so the first time it'll always return false.
    #
    def _content_modified?
      return false unless RbConfig::CONFIG['target_os'] =~ /darwin/i
      return false unless _mtime.to_i == Time.now.to_i

      _set_md5
      if _record_data[:md5]
        md5 != _record_data[:md5]
      else
        _set_record_data
        false
      end
    end

    def _set_record_data
      @data.merge!(_new_data)
      _record.async.set_path(path, data)
    end

    def _unset_record_data
      _record.async.unset_path(path)
    end

    def _new_data
      data = { mtime: _mtime, mode: _mode }
      data[:md5] = md5 if md5
      data
    end

    def _record_data
      @_record_data ||= _record.future.file_data(path).value
    end

    def _record
      listener.registry[:record]
    end

    def _mtime
      @mtime ||= _lstat.mtime.to_f
    rescue
      0.0
    end

    def _mode
      @mode ||= _lstat.mode
    rescue
      nil
    end

    def _lstat
      @lstat ||= ::File.lstat(path)
    rescue
      nil
    end

    def _set_md5
      @md5 = Digest::MD5.file(path).digest
    rescue
      nil
    end
  end
end
