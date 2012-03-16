require 'rbconfig'

module Listen
  class Adapter
    attr_accessor :latency, :stop, :paused

    # The default delay between checking for changes.
    DEFAULT_LATENCY = 0.1
    # The default warning message when falling back to polling adapter.
    POLLING_FALLBACK_MESSAGE = "WARNING: Listen fallen back to polling, learn more at https://github.com/guard/listen#fallback."

    # Select the appropriate adapter implementation for the
    # current OS and initializes it.
    #
    # @param [String, Pathname] directory the directory to watch
    # @param [Hash] options the adapter options
    # @option options [Boolean] force_polling to force polling or not
    # @option options [String, Boolean] polling_fallback_message to change polling fallback message or remove it
    # @option options [Float] latency the delay between checking for changes in seconds
    #
    # @yield [changed_dirs, options] callback Callback called when a change happens
    # @yieldparam [Array<String>] changed_dirs the changed directories
    # @yieldparam [Hash] options callback options (like :recursive => true)
    #
    # @return [Listen::Adapter] the chosen adapter
    #
    def self.select_and_initialize(directory, options = {}, &callback)
      return Adapters::Polling.new(directory, options, &callback) if options.delete(:force_polling)

      if Adapters::Darwin.usable_and_work?(directory, options)
        Adapters::Darwin.new(directory, options, &callback)
      elsif Adapters::Linux.usable_and_work?(directory, options)
        Adapters::Linux.new(directory, options, &callback)
      elsif Adapters::Windows.usable_and_work?(directory, options)
        Adapters::Windows.new(directory, options, &callback)
      else
        unless options[:polling_fallback_message] == false
          Kernel.warn(options[:polling_fallback_message] || POLLING_FALLBACK_MESSAGE)
        end
        Adapters::Polling.new(directory, options, &callback)
      end
    end

    # Initialize the adapter.
    #
    # @param [String, Pathname] directory the directory to watch
    # @param [Hash] options the adapter options
    # @option options [Float] latency the delay between checking for changes in seconds
    #
    # @yield [changed_dirs, options] callback Callback called when a change happens
    # @yieldparam [Array<String>] changed_dirs the changed directories
    # @yieldparam [Hash] options callback options (like :recursive => true)
    #
    # @return [Listen::Adapter] the adapter
    #
    def initialize(directory, options = {}, &callback)
      @directory = directory
      @callback  = callback
      @latency ||= DEFAULT_LATENCY
      @latency   = options[:latency] if options[:latency]
      @paused    = false
      @mutex     = Mutex.new
    end

    # Start the adapter.
    #
    def start
      @stop = false
    end

    # Stop the adapter.
    #
    def stop
      @stop = true
    end

  private

    # Check if the adapter is usable and works on the current OS.
    #
    # @param [String, Pathname] directory the directory to watch
    # @param [Hash] options the adapter options
    # @option options [Float] latency the delay between checking for changes in seconds
    #
    # @return [Boolean] whether usable and work or not
    #
    def self.usable_and_work?(directory, options = {})
      usable? && work?(directory, options)
    end

    # Check if the adapter is really working on the current OS by actually testing it.
    # This test take some time depending the adapter latency (max latency + 0.2 seconds).
    #
    # @param [String, Pathname] directory the directory to watch
    # @param [Hash] options the adapter options
    # @option options [Float] latency the delay between checking for changes in seconds
    #
    # @return [Boolean] whether work or not
    #
    def self.work?(directory, options = {})
      @work = false
      callback = lambda { |changed_dirs, options| @work = true }
      adapter  = self.new(directory, options, &callback)
      adapter.start
      FileUtils.touch "#{directory}/.listen_test"
      sleep adapter.latency + 0.1 # wait for callback
      @work
    ensure
      FileUtils.rm "#{directory}/.listen_test"
    end

  end
end
