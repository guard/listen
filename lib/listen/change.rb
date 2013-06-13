module Listen
  class Change
    include Celluloid

    def change(path, options)
      send("_#{options[:type].downcase}_change", path, options)
    end

    private

    def _file_change(path, options)
      change = File.new(path).change
      if change && _listener.listen?
        _notify_listener(change, path)
      end
    end

    def _dir_change(path, options)
      Directory.new(path, options).scan
    end

    def _notify_listener(change, path)
      _listener.mailbox << { change => path }
    end

    def _listener
      Actor[:listener]
    end
  end
end
