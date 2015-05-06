require 'set'

module Listen
  class Directory
    def self.scan(queue, sync_record, dir, rel_path, options)
      return unless (record = sync_record.async)

      previous = sync_record.dir_entries(dir, rel_path)

      record.add_dir(dir, rel_path)

      # TODO: use children(with_directory: false)
      path = dir + rel_path
      current = Set.new(path.children)

      _log(:debug) do
        format('%s: %s(%s): %s -> %s',
               (options[:silence] ? 'Recording' : 'Scanning'),
               rel_path, options.inspect, previous.inspect, current.inspect)
      end

      current.each do |full_path|
        type = full_path.directory? ? :dir : :file
        item_rel_path = full_path.relative_path_from(dir).to_s
        _change(queue, type, dir, item_rel_path, options)
      end

      # TODO: this is not tested properly
      previous = previous.reject { |entry, _| current.include? path + entry }

      _async_changes(dir, rel_path, queue, previous, options)

    rescue Errno::ENOENT, Errno::EHOSTDOWN
      record.unset_path(dir, rel_path)
      _async_changes(dir, rel_path, queue, previous, options)

    rescue Errno::ENOTDIR
      # TODO: path not tested
      record.unset_path(dir, rel_path)
      _async_changes(dir, path, queue, previous, options)
      _change(queue, :file, dir, rel_path, options)
    rescue
      _log(:warn) do
        format('scan DIED: %s:%s', $ERROR_INFO, $ERROR_POSITION * "\n")
      end
      raise
    end

    def self._async_changes(dir, path, queue, previous, options)
      previous.each do |entry, data|
        # TODO: this is a hack with insufficient testing
        type = data.key?(:mtime) ? :file : :dir
        _change(queue, type, dir, (Pathname(path) + entry).to_s, options)
      end
    end

    def self._change(queue, type, dir, path, options)
      return queue.change(type, dir, path, options) if type == :dir

      # Minor param cleanup for tests
      # TODO: use a dedicated Event class
      opts = options.dup
      opts.delete(:recursive)
      if opts.empty?
        queue.change(type, dir, path)
      else
        queue.change(type, dir, path, opts)
      end
    end

    def self._log(type, &block)
      return unless Celluloid.logger
      Celluloid.logger.send(type) do
        block.call
      end
    end
  end
end
