# frozen_string_literal: true

module Listen
  class Options
    def initialize(opts, defaults)
      @options = {}
      given_options = opts.dup
      defaults.keys.each do |key|
        @options[key] = given_options.delete(key) || defaults[key]
      end

      return if given_options.empty?

      msg = "Unknown options: #{given_options.inspect}"
      Listen.logger.warn msg
      fail msg
    end

    def method_defined?(name, *_)
      @options.has_key?(name)
    end

    def method_missing(name, *_)
      method_defined?(name) or raise NameError, "Bad option: #{name.inspect} (valid:#{@options.keys.inspect})"
      @options[name]
    end
  end
end
