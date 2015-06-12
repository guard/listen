module Listen
  class EventProcessor
    class Config
      def initialize(listener, event_queue, queue_optimizer)
        @listener = listener
        @event_queue = event_queue
        @queue_optimizer = queue_optimizer
      end

      def stopped?
        listener.state == :stopped
      end

      def paused?
        listener.state == :paused
      end

      def sleep(*args)
        Kernel.sleep(*args)
      end

      def call(*args)
        listener.block.call(*args)
      end

      def last_queue_event_time
        # TODO: fix
        listener.send(:last_queue_event_time)
      end

      def timestamp
        Time.now.to_f
      end

      def event_queue
        @event_queue
      end

      def reset_last_queue_event_time
        listener.send(:last_queue_event_time=, nil)
      end

      def callable?
        listener.block
      end

      def optimize_changes(changes)
        @queue_optimizer.smoosh_changes(changes)
      end

      private

      attr_reader :listener
    end

    def initialize(config)
      @config = config
    end

    # TODO: implement this properly instead of checking the state at arbitrary
    # points in time
    def loop_for(latency)
      loop do
        break if config.stopped?

        if config.paused? || config.event_queue.empty?
          config.sleep
          break if config.stopped?
        end

        # Assure there's at least latency between callbacks to allow
        # for accumulating changes
        now = config.timestamp
        diff = latency + (config.last_queue_event_time || now) - now
        if diff > 0
          # give events a bit of time to accumulate so they can be
          # compressed/optimized
          config.sleep(diff)
          next
        end

        _process_changes unless config.paused?
      end
    end

    private

    # for easier testing without sleep loop
    def _process_changes
      return if config.event_queue.empty? # e.g. ignored changes

      config.reset_last_queue_event_time

      changes = []
      changes << config.event_queue.pop until config.event_queue.empty?

      callable =  config.callable?
      return unless callable

      hash = config.optimize_changes(changes)
      result = [hash[:modified], hash[:added], hash[:removed]]
      return if result.all?(&:empty?)

      block_start = config.timestamp
      config.call(*result)
      Listen.logger.debug "Callback took #{Time.now.to_f - block_start} seconds"
    end

    attr_reader :config
  end
end
