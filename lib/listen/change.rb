require 'listen/record'
require 'listen/directory'
require 'listen/file'
require 'listen/silencer'

module Listen
  class Change
    include Celluloid

    def change(path, options)

      Actor[:listener].mailbox << Array(paths)
    end

  end
end
