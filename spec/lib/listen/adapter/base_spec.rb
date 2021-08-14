# frozen_string_literal: true

RSpec.describe Listen::Adapter::Base do
  class FakeAdapter < described_class
    def initialize(config)
      @my_callbacks = {}
      super
    end

    def _run
      fail NotImplementedError
    end

    def _configure(dir, &callback)
      @my_callbacks[dir.to_s] = callback
    end

    def fake_event(event)
      dir = event[:dir]
      @my_callbacks[dir].call(event)
    end

    def _process_event(dir, event)
      _queue_change(:file, dir, event[:file], cookie: event[:cookie])
    end
  end

  let(:thread) { instance_double(Thread, "thread") }
  let(:dir1) { instance_double(Pathname, 'dir1', to_s: '/foo/dir1') }

  let(:config) { instance_double(Listen::Adapter::Config) }
  let(:queue) { instance_double(Queue) }
  let(:silencer) { instance_double(Listen::Silencer) }
  let(:adapter_options) { {} }

  let(:snapshot) { instance_double(Listen::Change) }
  let(:record) { instance_double(Listen::Record) }

  subject { FakeAdapter.new(config) }

  before do
    allow(config).to receive(:directories).and_return([dir1])
    allow(config).to receive(:queue).and_return(queue)
    allow(config).to receive(:silencer).and_return(silencer)
    allow(config).to receive(:adapter_options).and_return(adapter_options)

    allow(Thread).to receive(:new) do |&block|
      block.call
      allow(thread).to receive(:name=)
      thread
    end

    # Stuff that happens in configure()
    allow(Listen::Record).to receive(:new).with(dir1, silencer).and_return(record)

    allow(Listen::Change::Config).to receive(:new).with(queue, silencer).
      and_return(config)

    allow(Listen::Change).to receive(:new).with(config, record).
      and_return(snapshot)
  end

  describe '#start' do
    before do
      allow(subject).to receive(:_run)

      allow(snapshot).to receive(:record).and_return(record)
      allow(record).to receive(:build)
    end

    it 'builds record' do
      expect(record).to receive(:build)
      subject.start
    end

    it 'runs the adapter' do
      expect(subject).to receive(:_run)
      subject.start
    end
  end

  describe 'handling events' do
    before do
      allow(subject).to receive(:_run)

      allow(snapshot).to receive(:record).and_return(record)
      allow(record).to receive(:build)
    end

    context 'when an event occurs' do
      it 'passes invalidates the snapshot based on the event' do
        subject.start

        expect(snapshot).to receive(:invalidate).with(:file, 'bar', cookie: 3)

        event = { dir: '/foo/dir1', file: 'bar', type: :moved, cookie: 3 }
        subject.fake_event(event)
      end
    end
  end
end
