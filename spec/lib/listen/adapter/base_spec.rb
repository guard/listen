require 'spec_helper'

describe Listen::Adapter::Base do
  let(:adapter) { described_class.new(listener) }
  let(:registry) { double(Celluloid::Registry) }
  let(:listener) { double(Listen::Listener, registry: registry, options: {}) }

  describe "#_latency" do
    it "returns default_latency with listener actor latency not present" do
      expect(adapter.send(:_latency)).to eq Listen::Adapter::Base::DEFAULT_LATENCY
    end

    it "returns latency from listener actor if present" do
      listener.stub(:options) { { latency: 1234 } }
      expect(adapter.send(:_latency)).to eq 1234
    end
  end

  describe "#_notify_change" do
    let(:change_pool) { double(Listen::Change) }
    let(:change_pool_async) { double('ChangePoolAsync') }
    before {
      change_pool.stub(:async) { change_pool_async }
      registry.stub(:[]).with(:change_pool) { change_pool }
    }

    context "listener listen" do
      before { listener.stub(:listen?) { true} }

      it "calls change on change_pool asynchronously" do
        expect(change_pool_async).to receive(:change).with('path', type: 'Dir', recurcise: true)
        adapter.send(:_notify_change, 'path', type: 'Dir', recurcise: true)
      end
    end

    context "listener doesn't listen" do
      before { listener.stub(:listen?) { false } }

      it "calls change on change_pool asynchronously" do
        expect(change_pool_async).to_not receive(:change)
        adapter.send(:_notify_change, 'path', type: 'Dir', recurcise: true)
      end
    end
  end
end
