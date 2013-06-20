module Listen
  class File
    attr_accessor :path, :data

    def initialize(path)
      @path = path
      @data = { type: 'File' }
    end

    def change
      if _existing_path?
        modified = _modified?
        p "file modified: #{_mtime}" if _modified?
        _set_record_data
        :modified if modified
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
      (_mtime == _record_data[:mtime] && (_content_modified? || _mode_modified?)) ||
        _mtime > _record_data[:mtime]
    end

    def _content_modified?
      @data.merge!(md5: _md5)
      _record_data[:md5] && _md5 != _record_data[:md5]
    end

    def _mode_modified?
      @data.merge!(mode: _mode)
      _record_data[:mode] && _mode != _record_data[:mode]
    end

    def _set_record_data
      @data.merge!(mtime: _mtime)
      _record.async.set_path(path, data)
    end

    def _unset_record_data
      _record.async.unset_path(path)
    end

    def _record_data
      @_record_data ||= _record.future.file_data(path).value
    end

    def _record
      Celluloid::Actor[:listen_record]
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

    def _md5
      @md5 ||= Digest::MD5.file(path).digest
    rescue
      nil
    end
  end
end
