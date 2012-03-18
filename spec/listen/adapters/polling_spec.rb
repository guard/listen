require 'spec_helper'

describe Listen::Adapters::Polling do
  subject { described_class.new('dir') }

  describe '#initialize' do
    it 'sets the latency to the default polling one' do
      subject.latency.should eq Listen::Adapters::DEFAULT_POLLING_LATENCY
    end
  end

  describe "#poll" do
    let(:listener) { mock(Listen::Listener)}
    let(:callback) { lambda { |changed_dirs, options| @called = true; listener.on_change(changed_dirs, options) } }
    subject { Listen::Adapters::Polling.new('dir', {}, &callback) }

    after { subject.stop }

    it "calls listener.on_change" do
      listener.should_receive(:on_change).at_least(1).times.with(['dir'], :recursive => true)
      subject.start
      subject.wait_for_callback
    end

    it "calls listener.on_change continuously" do
      subject.latency = 0.001
      listener.should_receive(:on_change).at_least(10).times.with(['dir'], :recursive => true)
      subject.start
      10.times { subject.wait_for_callback }
    end

    it "doesn't call listener.on_change if paused" do
      subject.paused = true
      subject.start
      subject.wait_for_callback
      @called.should be_nil
    end
  end
end
