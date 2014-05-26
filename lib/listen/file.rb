module Listen
  class File
    def self.change(record, path)
      lstat = path.lstat

      data = { type: 'File', mtime: lstat.mtime.to_f, mode: lstat.mode }

      record_data = record.file_data(path)

      if record_data.empty?
        record.async.set_path(path, data)
        return :added
      end

      if data[:mode] != record_data[:mode]
        record.async.set_path(path, data)
        return :modified
      end

      if data[:mtime] > record_data[:mtime]
        record.async.set_path(path, data)
        return :modified
      end

      unless /1|true/ =~ ENV['LISTEN_GEM_DISABLE_HASHING']
        # On Darwin comparing mtime because of the file mtime second precision.
        if RbConfig::CONFIG['target_os'] =~ /darwin/i
          if data[:mtime].to_i == Time.now.to_i
            md5 = Digest::MD5.file(path).digest
            if md5 != record_data[:md5]
              record.async.set_path(path, data.merge(md5: md5))
              :modified
            end
          end
        end
      end
    rescue SystemCallError
      record.async.unset_path(path)
      :removed
    rescue
      Celluloid::Logger.debug "lstat failed for: #{path} (#{$!})"
      raise
    end
  end
end
