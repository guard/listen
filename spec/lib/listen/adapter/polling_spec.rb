require 'spec_helper'

describe Listen::Adapter::Polling do
  describe 'class' do
    subject { described_class }
    it { should be_local_fs }
    it { should be_usable }
  end

  subject { described_class.new(listener) }

  let(:options) { {} }
  let(:listener) { instance_double(Listen::Listener, options: options) }
  let(:worker) { instance_double(Listen::Change) }

  before { allow(listener).to receive(:async).with(:change_pool) { worker } }

  describe '#start' do
    before { allow(listener).to receive(:directories) { ['directory_path'] } }

    it 'notifies change on every listener directories path' do
      expect(worker).to receive(:change).with(
        :dir,
        'directory_path',
        recursive: true)

      t = Thread.new { subject.start }
      sleep 0.25
      t.kill
    end
  end

  describe '#_latency' do
    subject { described_class.new(listener).send(:_latency) }

    context 'with no overriding option' do
      it { should eq described_class.const_get('DEFAULT_POLLING_LATENCY') }
    end

    context 'with custom latency overriding' do
      let(:options) { { latency: 1234 } }
      it { should eq 1234 }
    end
  end
end
