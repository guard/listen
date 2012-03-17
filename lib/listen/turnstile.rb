module Listen
  # Allows two threads to wait on eachother.
  #
  # @note Only two threads can be used with this Turnstile
  #   because of the current implementation.
  class Turnstile
    def initialize
      # Until ruby offers semahpores, only queues can be used
      # to implement a turnstile.
      @q = Queue.new
    end

    def wait
      @q.pop if @q.num_waiting == 0
    end

    def signal
      @q.push :dummy if @q.num_waiting == 1
    end
  end
end
