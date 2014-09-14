require 'listen/file'
require 'listen/directory'

module Listen
  class Change
    include Celluloid

    attr_accessor :listener

    def initialize(listener)
      @listener = listener
    end

    def change(type, watched_dir, rel_path, options = {})
      change = options[:change]
      cookie = options[:cookie]

      if !cookie && listener.silencer.silenced?(Pathname(rel_path), type)
        _log :debug, "(silenced): #{rel_path.inspect}"
        return
      end

      path = watched_dir + rel_path

      log_details = options[:silence] && 'recording' || change || 'unknown'
      _log :debug, "#{log_details}: #{type}:#{path} (#{options.inspect})"

      if change
        # TODO: move this to Listener to avoid Celluloid overhead
        # from caller
        options = cookie ? { cookie: cookie } : {}
        listener.queue(type, change, watched_dir, rel_path, options)
      else
        return unless (record = listener.sync(:record))

        if type == :dir
          return unless (change_queue = listener.async(:change_pool))
          Directory.scan(change_queue, record, watched_dir, rel_path, options)
        else
          change = File.change(record, watched_dir, rel_path)
          return if !change || options[:silence]
          listener.queue(:file, change, watched_dir, rel_path)
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
      Celluloid::Logger.send(type, message)
    end
  end
end
