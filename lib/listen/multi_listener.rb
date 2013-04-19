module Listen
  class MultiListener < Listener

    # This class is deprecated, please use Listen::Listener instead.
    #
    # @see Listen::Listener
    # @deprecated
    #
    def initialize(*args, &block)
      puts "[DEPRECATED] Listen::MultiListener is deprecated, please use Listen::Listener instead."
      super
    end

  end
end
