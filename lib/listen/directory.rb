require 'set'

module Listen
  class Directory
    def self.scan(queue, sync_record, path, options = {})
      return unless (record = sync_record.async)

      _log :debug, "Scanning: #{path.to_s.inspect}"

      previous = sync_record.dir_entries(path)

      record.set_path(path, type: 'Dir')
      current = Set.new(path.children)
      current.each do |full_path|
        if full_path.directory?
          if options[:recursive]
            _change(queue, full_path, options.merge(type: 'Dir'))
          end
        else
          _change(queue, full_path, options.merge(type: 'File'))
        end
      end

      previous.reject! { |entry, _| current.include? entry }
      _async_changes(path, queue, previous, options)

    rescue Errno::ENOENT
      record.unset_path(path)
      _async_changes(path, queue, previous, options)

    rescue Errno::ENOTDIR
      # TODO: path not tested
      record.unset_path(path)
      _async_changes(path, queue, previous, options)
      _change(queue, path, options.merge(type: 'File'))

    rescue
      _log :warn, "scanning DIED: #{$!}:#{$@.join("\n")}"
      raise
    end

    def self._async_changes(path, queue, previous, options)
      previous.each do |entry, data|
        _change(queue, path + entry, options.merge(type: data[:type]))
      end
    end

    def self._change(queue, full_path, options)
      return queue.change(full_path, options) if options[:type] == 'Dir'
      opts = options.dup
      opts.delete(:recursive)
      queue.change(full_path, opts)
    end

    def self._log(type, message)
      Celluloid.logger.send(type, message)
    end
  end
end
