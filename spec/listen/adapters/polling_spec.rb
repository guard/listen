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
    let(:callback) { lambda { |changed_dirs, options| listener.on_change(changed_dirs, options) } }
    subject { Listen::Adapters::Polling.new('dir', {}, &callback) }

    it "calls listener.on_change" do
      listener.should_receive(:on_change).at_least(1).times.with(['dir'], :recursive => true)
      Thread.new { subject.start }
      sleep 0.1
    end

    it "calls listener.on_change continuously" do
      subject.latency = 0.001
      listener.should_receive(:on_change).at_least(10).times.with(['dir'], :recursive => true)
      Thread.new { subject.start }
      sleep 0.1
    end
  end
end
