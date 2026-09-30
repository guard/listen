# frozen_string_literal: true

include Listen

RSpec.describe Adapter::Polling do
  describe 'class' do
    subject { described_class }
    it { should be_usable }
  end

  subject do
    described_class.new(config)
  end

  let(:dir1) do
    instance_double(Pathname, 'dir1', to_s: '/foo/dir1', cleanpath: real_dir1)
  end

  # just so cleanpath works in above double
  let(:real_dir1) { instance_double(Pathname, 'dir1', to_s: '/foo/dir1') }

  let(:config) { instance_double(Listen::Adapter::Config, "config") }
  let(:directories) { [dir1] }
  let(:options) { {} }
  let(:queue) { instance_double(Queue, "queue") }
  let(:silencer) { instance_double(Listen::Silencer, "silencer") }
  let(:snapshot) { instance_double(Listen::Change, "snapshot") }

  let(:record) { instance_double(Listen::Record) }

  context 'with a valid configuration' do
    before do
      allow(config).to receive(:directories).and_return(directories)
      allow(config).to receive(:adapter_options).and_return(options)
      allow(config).to receive(:queue).and_return(queue)
      allow(config).to receive(:silencer).and_return(silencer)

      allow(Listen::Record).to receive(:new).with(dir1, silencer).and_return(record)

      allow(Listen::Change).to receive(:new).with(config, record).
        and_return(snapshot)
      allow(Listen::Change::Config).to receive(:new).with(queue, silencer).
        and_return(config)
    end

    describe '#start' do
      before do
        allow(snapshot).to receive(:record).and_return(record)
        allow(record).to receive(:build)
      end

      after do
        allow(queue).to receive(:close)
        subject.stop
      end

      it 'notifies change on every listener directories path' do
        expect(snapshot).to receive(:invalidate).
          with(:dir, '.', { recursive: true })

        t = Thread.new { subject.start }
        sleep 0.25
        t.kill
      end
    end

    describe '#_latency' do
      subject do
        adapter = described_class.new(config)
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
end
