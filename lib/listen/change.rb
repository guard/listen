require 'listen/file'
require 'listen/directory'

module Listen
  class Change
    include Celluloid

    attr_accessor :listener

    def initialize(listener)
      @listener = listener
    end

    def change(type, path, options = {})
      change = options[:change]
      cookie = options[:cookie]

      if !cookie && listener.silencer.silenced?(path, type)
        _log :debug, "(silenced): #{path.inspect}"
        return
      end

      log_details = options[:silence] && 'recording' || change || 'unknown'
      _log :debug, "#{log_details}: #{type}:#{path} (#{options.inspect})"

      if change
        listener.queue(type, change, path, cookie ? { cookie: cookie } : {})
      else
        return unless (record = listener.sync(:record))
        record.async.still_building! if options[:build]

        if type == :dir
          return unless (change_queue = listener.async(:change_pool))
          Directory.scan(change_queue, record, path, options)
        else
          change = File.change(record, path)
          return if !change || options[:silence]
          listener.queue(:file, change, path)
        end
      end
    rescue Celluloid::Task::TerminatedError
      _log :debug, "Change#change was terminated: #{$!.inspect}"
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
