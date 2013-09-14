RSpec.configuration.before(:each) do
  Celluloid.logger = nil
  Celluloid.shutdown
  Celluloid.boot
  if RUBY_PLATFORM != "java"
    class Celluloid::ActorProxy
      unless @rspec_compatible
        @rspec_compatible = true
        undef_method :should_receive
      end
    end
  end
end
