require 'spec_helper'

describe Listen::Adapters::Polling do

  describe "#poll" do
    let(:listener) { mock(Listen::Listener, :directory => 'path')}

    it "calls listener.on_change" do
      adapter = Listen::Adapters::Polling.new(listener)
      listener.should_receive(:on_change).at_least(1).times.with(listener.directory)
      Thread.new { adapter.start }
      sleep 0.1
      adapter.stop
    end

    it "calls listener.on_change continuously" do
      adapter = Listen::Adapters::Polling.new(listener)
      adapter.latency = 0.001
      listener.should_receive(:on_change).at_least(10).times.with(listener.directory)
      Thread.new { adapter.start }
      sleep 0.1
      adapter.stop
    end

  end

end
