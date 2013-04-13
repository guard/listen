module Listen
  class MultiListener < Listener

    # This class is deprecated, please use Listen::Listener instead.
    #
    # @see Listen::Listener
    # @deprecated
    #
    def initialize(*args, &block)
      Kernel.warn "[Listen warning]:\nListen::MultiListener is deprecated, please use Listen::Listener instead."
      super
    end

  end
end
