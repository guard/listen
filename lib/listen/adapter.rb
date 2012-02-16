require 'rbconfig'

module Listen
  class Adapter
    attr_accessor :latency

    # The default delay between checking for changes.
    DEFAULT_LATENCY = 0.1

    # Select the appropriate adapter implementation for the
    # current OS and initializes it.
    #
    # @param [Listen::Listener] listener a listener for the changes
    # @param [Hash] options options for selecting the adapter
    # @option options [Boolean] force_polling whether to force the polling adapter or not
    #
    # @raise [RuntimeError] a runtime error will be raised when the use of the
    #   polling adapter is disabled and no OS-specific was suitable to be used.
    #
    # @return [Listen::Adapter] the chosen adapter
    #
    def self.select_and_initialize(listener, options = {})
      return Adapters::Polling.new(listener) if options[:force_polling]

      if Adapters::Darwin.usable?
        Adapters::Darwin.new(listener)
      elsif Adapters::Linux.usable?
        Adapters::Linux.new(listener)
      elsif Adapters::Windows.usable?
        Adapters::Windows.new(listener)
      else
        Adapters::Polling.new(listener)
      end
    end

    def initialize(listener)
      @listener = listener
      @latency  = DEFAULT_LATENCY
    end

    # Start the adapter.
    #
    def start
    end

    # Stop the adapter.
    #
    def stop
    end

  end
end
