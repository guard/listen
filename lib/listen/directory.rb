require 'set'

module Listen
  class Directory
    def self.scan(queue, sync_record, path, options = {})
      return unless (record = sync_record.async)

      previous = sync_record.dir_entries(path)

      record.set_path(:dir, path)
      current = Set.new(path.children)

      if options[:silence]
        _log :debug, "Recording: #{path}: #{options.inspect}"\
          " [#{previous.inspect}] -> (#{current.inspect})"
      else
        _log :debug, "Scanning: #{path}: #{options.inspect}"\
          " [#{previous.inspect}] -> (#{current.inspect})"
      end

      current.each do |full_path|
        if full_path.directory?
          _change(queue, :dir, full_path, options)
        else
          _change(queue, :file, full_path, options)
        end
      end

      previous.reject! { |entry, _| current.include? path + entry }
      _async_changes(path, queue, previous, options)

    rescue Errno::ENOENT
      record.unset_path(path)
      _async_changes(path, queue, previous, options)

    rescue Errno::ENOTDIR
      # TODO: path not tested
      record.unset_path(path)
      _async_changes(path, queue, previous, options)
      _change(queue, :file, path, options)
    rescue
      _log :warn, "scanning DIED: #{$!}:#{$@.join("\n")}"
      raise
    end

    def self._async_changes(path, queue, previous, options)
      previous.each do |entry, data|
        _change(queue, data[:type], path + entry, options)
      end
    end

    def self._change(queue, type, full_path, options)
      return queue.change(type, full_path, options) if type == :dir
      opts = options.dup
      opts.delete(:recursive)
      if opts.empty?
        queue.change(type, full_path)
      else
        queue.change(type, full_path, opts)
      end
    end

    def self._log(type, message)
      Celluloid.logger.send(type, message)
    end
  end
end
