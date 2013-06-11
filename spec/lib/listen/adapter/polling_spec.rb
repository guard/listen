require 'spec_helper'

describe Listen::Adapter::Polling do
  let(:adapter) { described_class.new }
  let(:listener) { MockActor.new }
  before { Celluloid::Actor[:listener] = listener }
  after { listener.terminate }

  describe ".usable?" do
    it "returns always true" do
      described_class.should be_usable
    end
  end

  describe "#start" do
    let(:directories_path) { ['directories_path'] }
    before { listener.stub(:options) { {} } }

    it "notifies change on every listener directories path" do
      listener.directories_path = directories_path
      adapter.async.start
      adapter.should_receive(:_notify_change).with('directories_path', type: 'Dir', recursive: true)
    end
  end

  describe "#_latency" do
    it "returns default_latency with listener actor latency not present" do
      adapter.send(:_latency).should eq Listen::Adapter::Polling::DEFAULT_POLLING_LATENCY
    end

    it "returns latency from listener actor if present" do
      listener.options[:latency] = 1234
      adapter.send(:_latency).should eq 1234
    end
  end
end
