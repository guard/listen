require 'spec_helper'

require 'listen/tcp/message'
require 'listen/tcp/broadcaster'

describe Listen::Listener do

  let(:host) { '10.0.0.2' }
  let(:port) { 4000 }

  subject { described_class.new("#{host}:#{port}", :recipient, options) }
  let(:options) { {} }
  let(:registry) { instance_double(Celluloid::Registry, :[]= => true) }

  let(:supervisor) do
    instance_double(Celluloid::SupervisionGroup, add: true, pool: true)
  end

  let(:record) { instance_double(Listen::Record, terminate: true, build: true) }
  let(:silencer) { instance_double(Listen::Silencer, configure: nil) }
  let(:adapter) { instance_double(Listen::Adapter::Base) }
  let(:async) { instance_double(Listen::TCP::Broadcaster, broadcast: true) }
  let(:broadcaster) { instance_double(Listen::TCP::Broadcaster, async: async) }
  let(:change_pool) { instance_double(Listen::Change, terminate: true) }
  let(:change_pool_async) { instance_double('ChangePoolAsync') }
  before do
    allow(Celluloid::Registry).to receive(:new) { registry }
    allow(Celluloid::SupervisionGroup).to receive(:run!) { supervisor }
    allow(registry).to receive(:[]).with(:adapter) { adapter }
    allow(registry).to receive(:[]).with(:record) { record }
    allow(registry).to receive(:[]).with(:change_pool) { change_pool }
    allow(registry).to receive(:[]).with(:broadcaster) { broadcaster }

    allow(Listen::Silencer).to receive(:new) { silencer }
  end

  describe '#initialize' do
    it 'raises on omitted target' do
      expect do
        described_class.new(nil, :recipient)
      end.to raise_error ArgumentError
    end
  end

  context 'when broadcaster' do
    subject { described_class.new(port, :broadcaster) }

    it 'does not force TCP adapter through options' do
      expect(subject.options).not_to include(force_tcp: true)
    end

    describe '#start' do
      before do
        allow(subject).to receive(:_start_adapter)
        allow(broadcaster).to receive(:start)
      end

      it 'registers broadcaster' do
        expect(supervisor).to receive(:add).
          with(Listen::TCP::Broadcaster, as: :broadcaster, args: [nil, port])
        subject.start
      end

      it 'starts broadcaster' do
        expect(broadcaster).to receive(:start)
        subject.start
      end
    end

    describe 'queue' do
      before do
        allow(broadcaster).to receive(:async).and_return async
      end

      context 'when stopped' do
        it 'honours stopped state and does nothing' do
          allow(subject).to receive(:supervisor) do
            instance_double(Celluloid::SupervisionGroup, terminate: true)
          end

          subject.stop
          subject.queue(:file, :modified, Pathname.pwd, 'foo')
          expect(broadcaster).not_to receive(:async)
        end
      end

      let(:dir) { Pathname.pwd }

      it 'broadcasts changes asynchronously' do
        message = Listen::TCP::Message.new(:file, :modified, dir, 'foo', {})
        expect(async).to receive(:broadcast).with message.payload
        subject.queue(:file, :modified, Pathname.pwd, 'foo')
      end
    end
  end

  context 'when recipient' do
    subject { described_class.new(port, :recipient) }

    it 'forces TCP adapter through options' do
      expect(subject.options).to include(force_tcp: true)
    end
  end
end
