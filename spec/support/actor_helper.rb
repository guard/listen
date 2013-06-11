RSpec.configuration.before(:each) do
  Celluloid.logger = nil
  Celluloid.shutdown
  Celluloid.boot
  class Celluloid::ActorProxy
    unless @rspec_compatible
      @rspec_compatible = true
      undef_method :should_receive
    end
  end
end

class MockActor
  include Celluloid

  attr_accessor :options, :directories_path

  def initialize
    @options = {}
  end
end
