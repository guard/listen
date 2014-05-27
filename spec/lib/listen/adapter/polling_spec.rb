require 'spec_helper'

describe Listen::Adapter::Polling do
  let(:registry) { instance_double(Celluloid::Registry) }
  let(:listener) do
    instance_double(
      Listen::Listener,
      registry: registry,
      options: {},
      listen?: true)
  end

  let(:adapter) { described_class.new(listener) }
  let(:proxy) { instance_double(Celluloid::ActorProxy, terminate: true) }
  let(:change_pool_async) { instance_double(Listen::Change) }

  before do
    allow(proxy).to receive(:async) { change_pool_async }
    allow(registry).to receive(:[]).with(:change_pool) { proxy }
  end

  describe '.usable?' do
    it 'returns always true' do
      expect(described_class).to be_usable
    end
  end

  describe '#start' do
    let(:directories) { ['directory_path'] }
    before do
      allow(listener).to receive(:options) { {} }
      allow(listener).to receive(:directories) { directories }
    end

    it 'notifies change on every listener directories path' do
      expect(change_pool_async).to receive(:change).with(
        :dir,
        'directory_path',
        recursive: true)

      t = Thread.new { adapter.start }
      sleep 0.25
      t.kill
    end
  end

  describe '#_latency' do
    it 'returns default_latency with listener actor latency not present' do
      expected_latency =  Listen::Adapter::Polling::DEFAULT_POLLING_LATENCY
      expect(adapter.send(:_latency)).to eq expected_latency
    end

    it 'returns latency from listener actor if present' do
      allow(listener).to receive(:options) { { latency: 1234 } }
      expect(adapter.send(:_latency)).to eq 1234
    end
  end

  specify { expect(described_class).to be_local_fs }

end
