require 'spec_helper'

describe Listen::Adapter::Polling do
  let(:listener) { MockActor.new }
  let(:adapter) { described_class.new(listener) }
  before { Celluloid::Actor[:listener] = listener }

  describe ".usable?" do
    it "returns always true" do
      described_class.should be_usable
    end
  end

  describe "#need_record?" do
    it "returns true" do
      adapter.need_record?.should be_true
    end
  end

  describe "#start" do
    let(:directories) { ['directory_path'] }
    before {
      listener.stub(:options) { {} }
      listener.directories = directories
    }

    it "notifies change on every listener directories path" do
      adapter.async.start
      adapter.should_receive(:_notify_change).with('directory_path', type: 'Dir', recursive: true)
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
