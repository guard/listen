require 'spec_helper'

describe Listen::Adapter::Polling do
  let(:registry) { double(Celluloid::Registry) }
  let(:listener) do
    double(Listen::Listener,
           registry: registry,
           options: {},
           listen?: true)
  end

  let(:adapter) { described_class.new(listener) }
  let(:change_pool) { double(Listen::Change, terminate: true) }
  let(:change_pool_async) { double('ChangePoolAsync') }

  before do
    change_pool.stub(:async) { change_pool_async }
    registry.stub(:[]).with(:change_pool) { change_pool }
  end

  describe '.usable?' do
    it 'returns always true' do
      expect(described_class).to be_usable
    end
  end

  describe '#start' do
    let(:directories) { ['directory_path'] }
    before do
      listener.stub(:options) { {} }
      listener.stub(:directories) { directories }
    end

    it 'notifies change on every listener directories path' do
      expect(change_pool_async).to receive(:change).with(
        'directory_path',
        type: 'Dir',
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
      listener.stub(:options) { { latency: 1234 } }
      expect(adapter.send(:_latency)).to eq 1234
    end
  end

  specify { expect(described_class).to be_local_fs }

end
