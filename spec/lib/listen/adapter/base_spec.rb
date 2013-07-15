require 'spec_helper'

describe Listen::Adapter::Base do
  let(:adapter) { described_class.new(listener) }
  let(:listener) { double(Listen::Listener, options: {}) }

  describe "#_latency" do
    it "returns default_latency with listener actor latency not present" do
      adapter.send(:_latency).should eq Listen::Adapter::Base::DEFAULT_LATENCY
    end

    it "returns latency from listener actor if present" do
      listener.stub(:options) { { latency: 1234 } }
      adapter.send(:_latency).should eq 1234
    end
  end

  describe "#_notify_change" do
    let(:change_pool) { double(Listen::Change) }
    let(:change_pool_async) { double('ChangePoolAsync') }
    before {
      change_pool.stub(:async) { change_pool_async }
      Celluloid::Actor.stub(:[]).with(:listen_change_pool) { change_pool }
    }

    context "listener listen" do
      before { listener.stub(:listen?) { true} }

      it "calls change on change_pool asynchronously" do
        change_pool_async.should_receive(:change).with('path', type: 'Dir', recurcise: true)
        adapter.send(:_notify_change, 'path', type: 'Dir', recurcise: true)
      end
    end

    context "listener doesn't listen" do
      before { listener.stub(:listen?) { false } }

      it "calls change on change_pool asynchronously" do
        change_pool_async.should_not_receive(:change)
        adapter.send(:_notify_change, 'path', type: 'Dir', recurcise: true)
      end
    end
  end
end
