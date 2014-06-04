require 'spec_helper'

include Listen

describe Adapter::Polling do
  describe 'class' do
    subject { described_class }
    it { should be_local_fs }
    it { should be_usable }
  end

  subject do
    described_class.new(options.merge(mq: mq, directories: directories))
  end

  let(:options) { {} }
  let(:mq) { instance_double(Listener, options: options) }

  describe '#start' do
    let(:directories) { [Pathname.pwd] }

    it 'notifies change on every listener directories path' do
      expect(mq).to receive(:_queue_raw_change).
        with(:dir, Pathname.pwd, '.', recursive: true)

      t = Thread.new { subject.start }
      sleep 0.25
      t.kill
    end
  end

  describe '#_latency' do
    subject do
      adapter = described_class.new(options.merge(mq: mq, directories: []))
      adapter.options.latency
    end

    context 'with no overriding option' do
      it { should eq 1.0 }
    end

    context 'with custom latency overriding' do
      let(:options) { { latency: 1234 } }
      it { should eq 1234 }
    end
  end
end
