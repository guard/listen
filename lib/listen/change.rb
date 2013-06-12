require 'listen/record'
require 'listen/directory'
require 'listen/file'
require 'listen/silencer'

module Listen
  class Change
    include Celluloid

    def change(path, options)
      send("_#{options[:type].downcase}_change", path, options)
    end

    private

    def _file_change(path, options)
      if change = File.new(path).change
        _notify_change(change, path)
      end
    end

    def _dir_change(path, options)
      Directory.new(path, options).change
    end

    def _notify_change(change, path)
      Actor[:listener].mailbox << { change => path }
    end
  end
end
