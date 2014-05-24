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
        if _silencer.silenced?(path, options[:type])
          _log :debug, "(silenced): #{path.inspect}"
          return
        end
      end

      _log :debug, "got change: #{[path, options].inspect}"

      if change
        _notify_listener(change, path, cookie ? { cookie: cookie } : {})
      else
        send("_#{options[:type].downcase}_change", path, options)
      end
    rescue Celluloid::Task::TerminatedError
      raise
    rescue RuntimeError
      _log :error, "Change#change crashed #{$!.inspect}:#{$@.join("\n")}"
      raise
    end

    private

    def _file_change(path, options)
      change = File.new(listener, path).change
      return if !change || !listener.listen? || options[:silence]

      _notify_listener(change, path)
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

    def _log(type, message)
      Celluloid.logger.send(type, message)
    end
  end
end
