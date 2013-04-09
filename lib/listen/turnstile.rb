module Listen

  # Allows two threads to wait on eachother.
  #
  # @note Only two threads can be used with this Turnstile
  #   because of the current implementation.
  class Turnstile

    # Initialize the turnstile.
    #
    def initialize
      # Until Ruby offers semahpores, only queues can be used
      # to implement a turnstile.
      @q = Queue.new
    end

    # Blocks the current thread until a signal is received.
    #
    def wait
      @q.pop if @q.num_waiting == 0
    end

    # Unblocks the waiting thread if any.
    #
    def signal
      @q.push(:dummy) if @q.num_waiting == 1
    end

  end

end
