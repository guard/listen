# frozen_string_literal: true

module Listen
  class Options
    def initialize(opts, defaults)
      @options = {}
      given_options = opts.dup
      defaults.each_key do |key|
        @options[key] = given_options.delete(key) || defaults[key]
      end

      return if given_options.empty?

      msg = "Unknown options: #{given_options.inspect}"
      Listen.logger.warn msg
      fail msg
    end

    def respond_to_missing?(name, *_)
      super || @options.has_key?(name)
    end

    def method_missing(name, *_)
      super || respond_to_missing?(name) or raise NameError, "Bad option: #{name.inspect} (valid:#{@options.keys.inspect})"
      @options[name]
    end
  end
end
