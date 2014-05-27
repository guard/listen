require 'spec_helper'

describe Listen::Adapter::Base do
  let(:adapter) { described_class.new(listener) }
  let(:registry) { instance_double(Celluloid::Registry) }

  let(:listener) do
    instance_double(Listen::Listener, registry: registry, options: {})
  end

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
    let(:proxy) { instance_double(Celluloid::ActorProxy) }
    let(:change_pool_async) { instance_double(Listen::Change) }
    before do
      allow(proxy).to receive(:async) { change_pool_async }
      allow(registry).to receive(:[]).with(:change_pool) { proxy }
    end

    context 'listener listen' do
      before { allow(listener).to receive(:listen?) { true } }

      it 'calls change on change_pool asynchronously' do
        expect(change_pool_async).to receive(:change).
          with(:dir, 'path', recursive: true)
        adapter.send(:_notify_change, :dir, 'path', recursive: true)
      end
    end

    context "listener doesn't listen" do
      before { allow(listener).to receive(:listen?) { false } }

      it 'calls change on change_pool asynchronously' do
        expect(change_pool_async).to_not receive(:change)
        adapter.send(:_notify_change, :dir, 'path', recursive: true)
      end
    end
  end
end
