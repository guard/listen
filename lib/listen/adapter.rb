module Listen
  class Adapter

    # Select the appropriate adapter implementation for the
    # current OS and initializes it.
    #
    # @return [Listen::Adapter] the chosen adapter
    #
    def self.select_and_initialize(listener)
      Adapters::Polling.new(listener)
    end

    def initialize(listener)
      @listener = listener
    end

  end
end
