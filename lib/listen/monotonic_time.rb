# frozen_string_literal: true

module Listen
  module MonotonicTime
    class << self
      def now
        if defined?(Process::CLOCK_MONOTONIC)
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        elsif defined?(Process::CLOCK_MONOTONIC_RAW)
          Process.clock_gettime(Process::CLOCK_MONOTONIC_RAW)
        else
          Time.now.to_f
        end
      end
    end
  end
end
