module Listen
  class File
    def self.change(record, path)
      lstat = path.lstat

      data = { mtime: lstat.mtime.to_f, mode: lstat.mode }

      record_data = record.file_data(path)

      if record_data.empty?
        record.async.set_path(:file, path, data)
        return :added
      end

      if data[:mode] != record_data[:mode]
        record.async.set_path(:file, path, data)
        return :modified
      end

      if data[:mtime] != record_data[:mtime]
        record.async.set_path(:file, path, data)
        return :modified
      end

      unless /1|true/ =~ ENV['LISTEN_GEM_DISABLE_HASHING']
        if self.inaccurate_mac_time?(lstat)
          if data[:mtime].to_i == Time.now.to_i
            begin
              md5 = Digest::MD5.file(path).digest
              record.async.set_path(:file, path, data.merge(md5: md5))
              :modified if record_data[:md5] && md5 != record_data[:md5]

            rescue SystemCallError
              # ignore failed md5
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

    def self.inaccurate_mac_time?(stat)
      # 'mac' means Modified/Accessed/Created

      # Since precision depends on mounted FS (e.g. you can have a FAT partiion
      # mounted on Linux), check for fields with a remainder to detect this

      [stat.mtime, stat.ctime, stat.atime].map(&:usec).all?(&:zero?)
    end
  end
end
