require 'listen/adapter/base'
require 'listen/adapter/bsd'
require 'listen/adapter/darwin'
require 'listen/adapter/linux'
require 'listen/adapter/polling'
require 'listen/adapter/windows'

module Listen
  module Adapter
    OPTIMIZED_ADAPTERS = %w[Darwin Linux BSD Windows]
    POLLING_FALLBACK_MESSAGE = "Listen will be polling for changes. Learn more at https://github.com/guard/listen#polling-fallback."

    def self.new(listener)
      adapter_class = _select(listener.options)
      adapter_class.new(listener)
    end

    private

    def self._select(options)
      return Polling if options[:force_polling] || not_mri?
      return _usable_adapter_class if _usable_adapter_class

      _warn_polling_fallback(options)
      Polling
    end

    def self._usable_adapter_class
      adapters = OPTIMIZED_ADAPTERS.map { |adapter| Adapter.const_get(adapter) }
      adapters.detect { |adapter| adapter.send(:usable?) }
    end

    def self._warn_polling_fallback(options)
      return if options[:polling_fallback_message] == false

      warning = options.fetch(:polling_fallback_message, POLLING_FALLBACK_MESSAGE)
      Kernel.warn "[Listen warning]:\n#{warning.gsub(/^(.*)/, '  \1')}"
    end

    def self.not_mri?
      RUBY_ENGINE != 'ruby'
    end
  end
end
