# frozen_string_literal: true

module Listen
  class Silencer
    class Controller
      def initialize(silencer, default_options)
        @silencer = silencer

        opts = default_options

        @prev_silencer_options = {}
        rules = [:only, :ignore, :ignore!].map do |option|
          [option, opts[option]] if opts.key? option
        end

        _reconfigure_silencer(Hash[rules.compact])
      end

      def append_ignores(*regexps)
        opts = @prev_silencer_options.dup
        opts[:ignore] = [opts[:ignore], regexps]
        _reconfigure_silencer(opts)
      end

      def replace_with_bang_ignores(regexps)
        opts = @prev_silencer_options.dup
        opts.delete(:ignore)
        opts[:ignore!] = regexps
        _reconfigure_silencer(opts)
      end

      def replace_with_only(regexps)
        opts = @prev_silencer_options.merge(only: regexps)
        _reconfigure_silencer(opts)
      end

      private

      def _reconfigure_silencer(extra_options)
        opts = extra_options.dup
        opts = opts.map do |key, value|
          [key, Array(value).flatten.compact]
        end
        opts = Hash[opts]

        if opts.key?(:ignore) && opts[:ignore].empty?
          opts.delete(:ignore)
        end

        @prev_silencer_options = opts
        @silencer.configure(@prev_silencer_options.dup.freeze)
      end
    end
  end
end
