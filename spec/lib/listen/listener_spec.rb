# frozen_string_literal: true

include Listen

RSpec.describe Listener do
  let(:realdir1) { fake_path('/foo/dir1', children: []) }
  let(:realdir2) { fake_path('/foo/dir2', children: []) }

  let(:dir1) { fake_path('dir1', realpath: realdir1) }
  let(:dir2) { fake_path('dir2', realpath: realdir2) }

  let(:dirs) { ['dir1'] }

  let(:block) { instance_double(Proc) }

  subject do
    described_class.new(*(dirs + [options]).compact) do |*changes|
      block.call(*changes)
    end
  end

  let(:options) { {} }

  let(:record) { instance_double(Record, build: true, root: 'dir2') }
  let(:silencer) { instance_double(Silencer, configure: nil) }

  let(:backend_class) { class_double('Listen::Backend') }

  let(:backend) { instance_double(Backend) }

  let(:optimizer_config) { instance_double(QueueOptimizer::Config) }
  let(:optimizer) { instance_double(QueueOptimizer) }

  let(:processor_config) { instance_double(Event::Config) }
  let(:processor) { instance_double(Event::Loop) }

  let(:event_queue) { instance_double(Event::Queue) }

  let(:default_latency) { 0.1 }
  let(:backend_wait_for_delay) { 0.123 }

  let(:processing_thread) { instance_double(Thread) }

  before do
    allow(Silencer).to receive(:new) { silencer }

    allow(Backend).to receive(:new).
      with(anything, event_queue, silencer, anything).
      and_return(backend)

    allow(backend).to receive(:min_delay_between_events).
      and_return(backend_wait_for_delay)

    # TODO: use a configuration object to clean this up

    allow(QueueOptimizer::Config).to receive(:new).with(backend, silencer).
      and_return(optimizer_config)

    allow(QueueOptimizer).to receive(:new).with(optimizer_config).
      and_return(optimizer)

    allow(Event::Queue).to receive(:new).and_return(event_queue)

    allow(Event::Config).to receive(:new).
      with(anything, event_queue, optimizer, backend_wait_for_delay).
      and_return(processor_config)

    allow(Event::Loop).to receive(:new).with(processor_config).
      and_return(processor)

    allow(Record).to receive(:new).and_return(record)

    allow(Pathname).to receive(:new).with('dir1').and_return(dir1)
    allow(Pathname).to receive(:new).with('dir2').and_return(dir2)

    allow(Thread).to receive(:new).and_return(processing_thread)
    allow(processing_thread).to receive(:alive?).and_return(true)
    allow(processing_thread).to receive(:wakeup)
    allow(processing_thread).to receive(:join)

    allow(block).to receive(:call)
  end

  describe 'initialize' do
    it { should_not be_paused }

    context 'with a block' do
      let(:myblock) { instance_double(Proc) }
      let(:block) { proc { myblock.call } }
      subject do
        described_class.new('dir1') do |*args|
          myblock.call(*args)
        end
      end

      it 'passes the block to the event processor' do
        allow(Event::Config).to receive(:new) do |*_args, &some_block|
          expect(some_block).to be
          some_block.call
          processor_config
        end
        expect(myblock).to receive(:call)
        subject
      end
    end

    context 'with directories' do
      subject { described_class.new('dir1', 'dir2') }

      it 'passes directories to backend' do
        allow(Backend).to receive(:new).
          with(%w[dir1 dir2], anything, anything, anything).
          and_return(backend)
        subject
      end
    end
  end

  describe '#start' do
    before do
      allow(backend).to receive(:start)
      allow(silencer).to receive(:silenced?) { false }
    end

    it 'sets paused to false' do
      allow(processor).to receive(:start)
      subject.start
      expect(subject).to_not be_paused
    end

    it 'starts adapter' do
      expect(backend).to receive(:start)
      allow(processor).to receive(:start)
      subject.start
    end
  end

  describe '#stop' do
    before do
      allow(backend).to receive(:start)
      allow(processor).to receive(:start)
    end

    context 'when fully started' do
      before do
        subject.start
      end

      it 'terminates' do
        allow(backend).to receive(:stop)
        allow(processor).to receive(:stop)
        subject.stop
      end
    end

    context 'when only initialized' do
      before do
        subject
      end

      it 'terminates' do
        allow(backend).to receive(:stop)
        allow(processor).to receive(:stop)
        subject.stop
      end
    end
  end

  describe '#pause' do
    before do
      allow(backend).to receive(:start)
      allow(processor).to receive(:start)
      subject.start
    end
    it 'sets paused to true' do
      allow(processor).to receive(:pause)
      subject.pause
      expect(subject).to be_paused
    end
  end

  describe 'unpause with start' do
    before do
      allow(backend).to receive(:start)
      allow(processor).to receive(:start)
      subject.start
      allow(processor).to receive(:pause)
      subject.pause
    end

    it 'sets paused to false' do
      subject.start
      expect(subject).to_not be_paused
    end
  end

  describe '#paused?' do
    before do
      allow(backend).to receive(:start)
      allow(processor).to receive(:start)
      subject.start
    end

    it 'returns true when paused' do
      allow(processor).to receive(:pause)
      subject.pause
      expect(subject).to be_paused
    end

    it 'returns false when not paused' do
      expect(subject).not_to be_paused
    end
  end

  describe '#listen?' do
    context 'when processing' do
      before do
        allow(backend).to receive(:start)
        allow(processor).to receive(:start)
        subject.start
      end
      it { should be_processing }
    end

    context 'when stopped' do
      it { should_not be_processing }
    end

    context 'when paused' do
      before do
        allow(backend).to receive(:start)
        allow(processor).to receive(:start)
        subject.start
        allow(processor).to receive(:pause)
        subject.pause
      end

      it { should_not be_processing }
    end
  end

  # TODO: move these to silencer_controller?
  describe '#ignore' do
    context 'with existing ignore options' do
      let(:options) { { ignore: /bar/ } }

      it 'adds up to existing ignore options' do
        expect(silencer).to receive(:configure).once.with({ ignore: [/bar/] })

        subject

        expect(silencer).to receive(:configure).once.
          with({ ignore: [/bar/, /foo/] })

        subject.ignore(/foo/)
      end
    end

    context 'with existing ignore options (array)' do
      let(:options) { { ignore: [/bar/] } }

      it 'adds up to existing ignore options' do
        expect(silencer).to receive(:configure).once.with({ ignore: [/bar/] })

        subject

        expect(silencer).to receive(:configure).once.
          with({ ignore: [/bar/, /foo/] })

        subject.ignore(/foo/)
      end
    end
  end

  # TODO: move these to silencer_controller?
  describe '#ignore!' do
    context 'with no existing options' do
      let(:options) { {} }

      it 'sets options' do
        expect(silencer).to receive(:configure).with(options)
        subject
      end
    end

    context 'with existing ignore! options' do
      let(:options) { { ignore!: /bar/ } }

      it 'overwrites existing ignore options' do
        expect(silencer).to receive(:configure).once.with({ ignore!: [/bar/] })
        subject
        expect(silencer).to receive(:configure).once.with({ ignore!: [/foo/] })
        subject.ignore!([/foo/])
      end
    end

    context 'with existing ignore options' do
      let(:options) { { ignore: /bar/ } }

      it 'deletes ignore options' do
        expect(silencer).to receive(:configure).once.with({ ignore: [/bar/] })
        subject
        expect(silencer).to receive(:configure).once.with({ ignore!: [/foo/] })
        subject.ignore!([/foo/])
      end
    end
  end

  describe '#only' do
    context 'with existing only options' do
      let(:options) { { only: /bar/ } }

      it 'overwrites existing ignore options' do
        expect(silencer).to receive(:configure).once.with({ only: [/bar/] })
        subject
        expect(silencer).to receive(:configure).once.with({ only: [/foo/] })
        subject.only([/foo/])
      end
    end
  end
end
