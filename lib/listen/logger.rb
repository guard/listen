module Listen
  def self.logger
    @logger
  end

  def self.logger=(logger)
    @logger = logger
  end

  class Logger
    %i(fatal error warn info debug).each do |meth|
      define_singleton_method(meth) do |*args, &block|
        Listen.logger.public_send(meth, *args, &block) if Listen.logger
      end
    end
  end
end
