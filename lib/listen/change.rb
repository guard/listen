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

      if !cookie && listener.silencer.silenced?(path, options[:type])
        _log :debug, "(silenced): #{path.inspect}"
        return
      end

      _log :debug, "got change: #{[path, options].inspect}"

      if change
        listener.queue(change, path, cookie ? { cookie: cookie } : {})
      else
        return unless (record = listener.sync(:record))

        if options[:type] == 'Dir'
          return unless (change_queue = listener.async(:change_pool))
          Directory.scan(change_queue, record, path, options)
        else
          change = File.change(record, path)
          return if !change || !listener.listen? || options[:silence]
          listener.queue(change, path)
        end
      end
    rescue Celluloid::Task::TerminatedError
      raise
    rescue RuntimeError
      _log :error, "Change#change crashed #{$!.inspect}:#{$@.join("\n")}"
      raise
    end

    private

    def _log(type, message)
      Celluloid.logger.send(type, message)
    end
  end
end
