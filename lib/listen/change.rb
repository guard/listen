require 'listen/file'
require 'listen/directory'

module Listen
  class Change
    class Config
      attr_reader :listener
      def initialize(listener)
        @listener = listener
      end

      def silenced?(path, type)
        listener.silencer.silenced?(Pathname(path), type)
      end

      def record_for(directory)
        listener.record_for(directory)
      end

      def queue(*args)
        listener.queue(*args)
      end
    end

    attr_reader :record

    def initialize(config, record)
      @config = config
      @record = record
    end

    def change(type, rel_path, options)
      watched_dir = Pathname.new(record.root)

      change = options[:change]
      cookie = options[:cookie]

      if !cookie && config.silenced?(rel_path, type)
        _log :debug, "(silenced): #{rel_path.inspect}"
        return
      end

      path = watched_dir + rel_path

      log_details = options[:silence] && 'recording' || change || 'unknown'
      _log :debug, "#{log_details}: #{type}:#{path} (#{options.inspect})"

      if change
        # TODO: move this to Listener to avoid overhead
        # from caller
        options = cookie ? { cookie: cookie } : {}
        config.queue(type, change, watched_dir, rel_path, options)
      else
        if type == :dir
          # NOTE: POSSIBLE RECURSION
          # TODO: fix - use a queue instead
          Directory.scan(self, rel_path, options)
        else
          change = File.change(record, rel_path)
          return if !change || options[:silence]
          config.queue(:file, change, watched_dir, rel_path)
        end
      end
    rescue RuntimeError
      _log :error, format('Change#change crashed %s:%s', $ERROR_INFO.inspect,
                          $ERROR_POSITION * "\n")
      raise
    end

    private

    attr_reader :config

    def _log(type, message)
      Listen::Logger.send(type, message)
    end
  end
end
