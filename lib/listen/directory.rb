require 'set'

module Listen
  class Directory
    def self.scan(fs_change, rel_path, options)
      record = fs_change.record
      dir = Pathname.new(record.root)
      previous = record.dir_entries(rel_path)

      record.add_dir(rel_path)

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
        _change(fs_change, type, item_rel_path, options)
      end

      # TODO: this is not tested properly
      previous = previous.reject { |entry, _| current.include? path + entry }

      _async_changes(fs_change, Pathname.new(rel_path), previous, options)

    rescue Errno::ENOENT, Errno::EHOSTDOWN
      record.unset_path(rel_path)
      _async_changes(fs_change, Pathname.new(rel_path), previous, options)

    rescue Errno::ENOTDIR
      # TODO: path not tested
      record.unset_path(rel_path)
      _async_changes(fs_change, path, previous, options)
      _change(fs_change, :file, rel_path, options)
    rescue
      _log(:warn) do
        format('scan DIED: %s:%s', $ERROR_INFO, $ERROR_POSITION * "\n")
      end
      raise
    end

    def self._async_changes(fs_change, path, previous, options)
      fail "Not a Pathname: #{path.inspect}" unless path.respond_to?(:children)
      previous.each do |entry, data|
        # TODO: this is a hack with insufficient testing
        type = data.key?(:mtime) ? :file : :dir
        rel_path_s = (path + entry).to_s
        _change(fs_change, type, rel_path_s, options)
      end
    end

    def self._change(fs_change, type, path, options)
      return fs_change.change(type, path, options) if type == :dir

      # Minor param cleanup for tests
      # TODO: use a dedicated Event class
      opts = options.dup
      opts.delete(:recursive)
      fs_change.change(type, path, opts)
    end

    def self._log(type, &block)
      return unless Celluloid.logger
      Celluloid.logger.send(type) do
        block.call
      end
    end
  end
end
