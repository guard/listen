require 'celluloid/logger'

module Listen
  module Internals
    module Logging
      def _info(*args)
        _log(:info, *args)
      end

      def _warn(*args)
        _log(:warn, *args)
      end

      def _debug(*args)
        _log(:debug, *args)
      end

      def _log(*args)
        Celluloid::Logger.send(*args)
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
