require 'celluloid/logger'

module Listen
  module Internals
    module Logging
      def _info(*args, &block)
        _log(:info, *args, &block)
      end

      def _warn(*args, &block)
        _log(:warn, *args, &block)
      end

      def _debug(*args, &block)
        _log(:debug, *args, &block)
      end

      def _log(*args, &block)
        if block
          Celluloid::Logger.send(*args, block.call)
        else
          Celluloid::Logger.send(*args)
        end
      end

      def _format_error(fmt)
        format(fmt, $ERROR_INFO, ", Backtrace: \n" + $ERROR_POSITION * "\n")
      end

      def _error_exception(fmt)
        _log :error, _format_error(fmt)
      end
    end
  end
end
