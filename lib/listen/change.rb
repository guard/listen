require 'listen/file'
require 'listen/directory'

module Listen
  class Change
    include Celluloid

    attr_accessor :listener

    def initialize(listener)
      @listener = listener
    end

    def change(path, options)
      change = options[:change]
      cookie = options[:cookie]

      unless cookie
        # TODO: remove silencing here (it's done later)
        return if _silencer.silenced?(path, options[:type])
      end

      if change
        _notify_listener(change, path, cookie ? { cookie: cookie } : {})
      else
        send("_#{options[:type].downcase}_change", path, options)
      end
    end

    private

    def _file_change(path, options)
      change = File.new(listener, path).change
      if change && listener.listen? && !options[:silence]
        _notify_listener(change, path)
      end
    end

    def _dir_change(path, options)
      Directory.new(listener, path, options).scan
    end

    def _notify_listener(change, path, options = {})
      listener.changes << { change => path }.merge(options)
    end

    def _silencer
      listener.registry[:silencer]
    end
  end
end
