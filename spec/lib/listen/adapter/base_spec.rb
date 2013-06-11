require 'spec_helper'

describe Listen::Adapter::Base do
  let(:adapter) { described_class.new }
  let(:listener) { MockActor.new }
  before { Celluloid::Actor[:listener] = listener }

  describe ".usable?" do
    it "raises when not implemented" do
      expect { described_class.usable? }.to raise_error(NotImplementedError)
    end
  end

  describe "#_latency" do
    it "returns default_latency with listener actor latency not present" do
      adapter.send(:_latency).should eq Listen::Adapter::Base::DEFAULT_LATENCY
    end

    it "returns latency from listener actor if present" do
      listener.options[:latency] = 1234
      adapter.send(:_latency).should eq 1234
    end
  end

  describe "#_directories_path" do
    let(:directories_path) { ['directories_path'] }

    it "returns directories path from listener actor" do
      listener.directories_path = directories_path
      adapter.send(:_directories_path).should eq directories_path
    end
  end

  describe "#_notify_change" do
    let(:change_pool) { MockActor.pool }
    let(:change_pool_async) { stub('ChangePoolAsync') }
    before {
      change_pool.stub(:async) { change_pool_async }
      Celluloid::Actor[:change_pool] = change_pool
    }

    it "calls change on change_pool asynchronously" do
      change_pool_async.should_receive(:change).with('path', type: 'Dir', recurcise: true)
      adapter.send(:_notify_change, 'path', type: 'Dir', recurcise: true)
    end
  end
end
