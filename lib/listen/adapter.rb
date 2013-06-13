module Listen
  module Adapter
    OPTIMIZED_ADAPTERS = %w[Darwin Linux BSD Windows]
    POLLING_FALLBACK_MESSAGE = "Listen will be polling for changes. Learn more at https://github.com/guard/listen#polling-fallback."

    def self.new
      adapter_class = _select
      adapter_class.new
    end

    private

    def self._select
      return Polling if _listener_options[:force_polling]
      return _usable_adapter_class if _usable_adapter_class

      _warn_polling_fallback
      Polling
    end

    def self._listener_options
      Celluloid::Actor[:listener].options
    end

    def self._usable_adapter_class
      adapters = OPTIMIZED_ADAPTERS.map { |adapter| Adapter.const_get(adapter) }
      adapters.detect { |adapter| adapter.send(:usable?) }
    end

    def self._warn_polling_fallback
      return if _listener_options[:polling_fallback_message] == false

      warning = _listener_options.fetch(:polling_fallback_message, POLLING_FALLBACK_MESSAGE)
      Kernel.warn "[Listen warning]:\n#{warning.gsub(/^(.*)/, '  \1')}"
    end
  end
end
