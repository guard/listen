require 'listen/file'
require 'listen/directory'
require 'listen/silencer'

module Listen
  class Change
    include Celluloid

    attr_accessor :listener, :silencer

    def initialize(listener)
      @listener = listener
      @silencer = Silencer.new(listener.options)
    end

    def change(path, options)
      return if silencer.silenced?(path)
      send("_#{options[:type].downcase}_change", path, options)
    end

    private

    def _file_change(path, options)
      change = File.new(path).change
      if change && listener.listen? && !options[:silence]
        _notify_listener(change, path)
      end
    end

    def _dir_change(path, options)
      Directory.new(path, options).scan
    end

    def _notify_listener(change, path)
      listener.changes << { change => path }
    end
  end
end
