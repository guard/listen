require 'spec_helper'

describe Listen::Adapter::Polling do
  let(:listener) { double(Listen::Listener, options: {}) }
  let(:adapter) { described_class.new(listener) }

  describe ".usable?" do
    it "returns always true" do
      expect(described_class).to be_usable
    end
  end

  describe "#start" do
    let(:directories) { ['directory_path'] }
    before {
      listener.stub(:options) { {} }
      listener.stub(:directories) { directories }
    }

    it "notifies change on every listener directories path" do
      adapter.should_receive(:_notify_change).with('directory_path', type: 'Dir', recursive: true)
      t = Thread.new { adapter.start }
      sleep 0.01
      t.kill
    end
  end

  describe "#_latency" do
    it "returns default_latency with listener actor latency not present" do
      adapter.send(:_latency).should eq Listen::Adapter::Polling::DEFAULT_POLLING_LATENCY
    end

    it "returns latency from listener actor if present" do
      listener.stub(:options) { { latency: 1234 } }
      adapter.send(:_latency).should eq 1234
    end
  end
end
