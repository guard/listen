require 'spec_helper'

describe Listen::Adapter::Base do
  let(:adapter) { described_class.new(listener) }
  let(:registry) { double(Celluloid::Registry) }
  let(:listener) { double(Listen::Listener, registry: registry, options: {}) }

  describe '#_latency' do
    it 'returns default_latency with listener actor latency not present' do
      latency = Listen::Adapter::Base::DEFAULT_LATENCY
      expect(adapter.send(:_latency)).to eq latency
    end

    it 'returns latency from listener actor if present' do
      allow(listener).to receive(:options) { { latency: 1234 } }
      expect(adapter.send(:_latency)).to eq 1234
    end
  end

  describe '#_notify_change' do
    let(:change_pool) { double(Listen::Change) }
    let(:change_pool_async) { double('ChangePoolAsync') }
    before do
      allow(change_pool).to receive(:async) { change_pool_async }
      allow(registry).to receive(:[]).with(:change_pool) { change_pool }
    end

    context 'listener listen' do
      before { allow(listener).to receive(:listen?) { true } }

      it 'calls change on change_pool asynchronously' do
        expect(change_pool_async).to receive(:change).
          with('path', type: 'Dir', recurcise: true)
        adapter.send(:_notify_change, 'path', type: 'Dir', recurcise: true)
      end
    end

    context "listener doesn't listen" do
      before { allow(listener).to receive(:listen?) { false } }

      it 'calls change on change_pool asynchronously' do
        expect(change_pool_async).to_not receive(:change)
        adapter.send(:_notify_change, 'path', type: 'Dir', recurcise: true)
      end
    end
  end
end
