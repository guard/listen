require 'spec_helper'

describe Listen::Adapters::Polling do

  describe "#poll" do
    let(:listener) { mock(Listen::Listener, :directory => 'path')}

    it "calls listener.on_change" do
      adapter = Listen::Adapters::Polling.new(listener)
      listener.should_receive(:on_change).with(listener.directory)
      Thread.new { adapter.start }
      sleep 0.001
      adapter.stop
    end

    it "calls listener.on_change continuously" do
      adapter = Listen::Adapters::Polling.new(listener)
      adapter.latency = 0.001
      listener.should_receive(:on_change).exactly(7).times.with(listener.directory)
      Thread.new { adapter.start }
      sleep 0.007
      adapter.stop
    end

  end

end
