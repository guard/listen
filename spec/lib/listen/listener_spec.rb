include Listen

RSpec.describe Listener do

  let(:realdir1) { instance_double(Pathname, '/foo/dir1', children: []) }
  let(:realdir2) { instance_double(Pathname, '/foo/dir2', children: []) }

  let(:queue) { instance_double(Queue) }

  let(:dir1) { instance_double(Pathname, 'dir1', realpath: realdir1) }
  let(:dir2) { instance_double(Pathname, 'dir2', realpath: realdir2) }

  let(:dirs) { ['dir1'] }

  subject { described_class.new(*(dirs + [options]).compact) }

  let(:options) { {} }

  let(:record) { instance_double(Record, build: true, root: 'dir2') }
  let(:silencer) { instance_double(Silencer, configure: nil) }

  let(:adapter_namespace) do
    class_double('Listen::Adapter').
      as_stubbed_const(transfer_nested_constants: true)
  end

  let(:adapter_class) { class_double('Listen::Adapter::Base') }
  let(:adapter) { instance_double('Listen::Adapter::Base', start: nil) }

  let(:optimizer_config) { instance_double(QueueOptimizer::Config) }
  let(:optimizer) { instance_double(QueueOptimizer) }

  let(:processor_config) { instance_double(EventProcessor::Config) }
  let(:processor) { instance_double(EventProcessor) }

  let(:default_latency) { 0.1 }

  before do
    allow(Silencer).to receive(:new) { silencer }

    # TODO: use a configuration object to clean this up
    allow(adapter_namespace).to receive(:select).
      with(anything).and_return(adapter_class)

    allow(adapter_class).to receive(:new).with(anything).and_return(adapter)
    allow(adapter_class).to receive(:local_fs?).and_return(true)
    allow(adapter).to receive(:class).and_return(adapter_class)

    allow(QueueOptimizer::Config).to receive(:new).
      with(adapter_class, silencer).and_return(optimizer_config)

    allow(QueueOptimizer).to receive(:new).with(optimizer_config).
      and_return(optimizer)

    allow(EventProcessor::Config).to receive(:new).
      with(anything, queue, optimizer).and_return(processor_config)

    allow(EventProcessor).to receive(:new).with(processor_config).
      and_return(processor)

    allow(processor).to receive(:loop_for).with(default_latency)

    allow(Record).to receive(:new).and_return(record)

    allow(Pathname).to receive(:new).with('dir1').and_return(dir1)
    allow(Pathname).to receive(:new).with('dir2').and_return(dir2)

    allow(Queue).to receive(:new).and_return(queue)
    allow(queue).to receive(:<<)
    allow(queue).to receive(:empty?).and_return(true)

    allow(Internals::ThreadPool).to receive(:add)
  end

  describe 'initialize' do
    it { should_not be_paused }

    context 'with a block' do
      describe 'block' do
        subject { described_class.new('dir1', &(proc {})) }
        specify { expect(subject.block).to_not be_nil }
      end
    end

    context 'with directories' do
      describe 'directories' do
        subject { described_class.new('dir1', 'dir2') }
        specify { expect(subject.directories).to eq([realdir1, realdir2]) }
      end
    end
  end

  describe 'options' do
    context 'with supported adapter option' do
      let(:options) { { latency: 1.234 } }
      before do
        allow(supervisor).to receive(:add)
        allow(Adapter).to receive(:select) { Adapter::Polling }
      end

      it 'passes adapter options to adapter' do
        expect(supervisor).to receive(:add).
          with(anything, hash_including(
            args: [hash_including(latency: 1.234)]
        ))
        subject.start
      end
    end

    context 'with unsupported adapter option' do
      let(:options) { { latency: 1.234 } }
      before do
        allow(supervisor).to receive(:add)
        allow(Adapter).to receive(:select) { Adapter::Linux }
      end

      it 'passes adapter options to adapter' do
        expect(supervisor).to_not receive(:add).
          with(anything, hash_including(
            args: [hash_including(latency: anything)]
        ))
        subject.start
      end
    end

    context 'default options' do
      it 'sets default options' do
        expect(subject.options).
          to eq(
            debug: false,
            wait_for_delay: 0.1,
            force_polling: false,
            relative: false,
            polling_fallback_message: nil)
      end
    end

    context 'custom options' do
      subject do
        described_class.new(
          'dir1',
          latency: 1.234,
          wait_for_delay: 0.85,
          relative: true)
      end

      it 'sets new options on initialize' do
        expect(subject.options).
          to eq(
            debug: false,
            latency: 1.234,
            wait_for_delay: 0.85,
            force_polling: false,
            relative: true,
            polling_fallback_message: nil)
      end
    end
  end

  describe '#start' do
    before do
      allow(adapter).to receive(:start)
      allow(silencer).to receive(:silenced?) { false }
    end

    it 'builds record' do
      expect(record).to receive(:build)
      subject.start
    end

    it 'sets paused to false' do
      subject.start
      expect(subject).to_not be_paused
    end

    it 'starts adapter' do
      expect(adapter).to receive(:start)
      subject.start
    end

    context 'when relative option is true' do
      before do
        current_path = instance_double(Pathname, to_s: '/project/path')
        allow(Pathname).to receive(:new).with(Dir.pwd).and_return(current_path)
      end

      context 'when watched dir is the current dir' do
        let(:options) { { relative: true, directories: Pathname.pwd } }
        it 'registers relative paths' do
          event_dir = instance_double(Pathname)
          dir_rel_path = instance_double(Pathname, to_s: '.')
          foo_rel_path = instance_double(Pathname, to_s: 'foo', exist?: true)

          allow(event_dir).to receive(:relative_path_from).
            with(Pathname.pwd).
            and_return(dir_rel_path)

          allow(dir_rel_path).to receive(:+).with('foo') { foo_rel_path }

          block_stub = instance_double(Proc)
          expect(block_stub).to receive(:call).with(['foo'], [], [])
          subject.block = block_stub

          subject.start
          subject.queue(:file, :modified, event_dir, 'foo')
          subject.block.call(['foo'], [], [])
          sleep 0.25
        end
      end

      context 'when watched dir is not the current dir' do
        let(:options) { { relative: true } }

        it 'registers relative path' do
          event_dir = instance_double(Pathname)
          dir_rel_path = instance_double(Pathname, to_s: '..')
          foo_rel_path = instance_double(Pathname, to_s: '../foo', exist?: true)

          allow(event_dir).to receive(:relative_path_from).
            with(Pathname.pwd).
            and_return(dir_rel_path)

          allow(dir_rel_path).to receive(:+).with('foo') { foo_rel_path }

          block_stub = instance_double(Proc)
          expect(block_stub).to receive(:call).with(['../foo'], [], [])
          subject.block = block_stub

          subject.start
          subject.queue(:file, :modified, event_dir, 'foo')
          subject.block.call(['../foo'], [], [])
        end
      end

      context 'when watched dir is on another drive' do
        let(:options) { { relative: true } }

        it 'registers full path' do
          event_dir = instance_double(Pathname, 'event_dir', realpath: 'd:/foo')

          foo_rel_path = instance_double(
            Pathname,
            'rel_path',
            to_s: 'd:/foo',
            exist?: true,
            children: []
          )

          allow(event_dir).to receive(:relative_path_from).
            with(Pathname.pwd).
            and_raise(ArgumentError)

          allow(event_dir).to receive(:+).with('foo') { foo_rel_path }

          block_stub = instance_double(Proc)
          expect(block_stub).to receive(:call).with(['d:/foo'], [], [])
          subject.block = block_stub

          subject.start
          subject.queue(:file, :modified, event_dir, 'foo')
          subject.block.call(['d:/foo'], [], [])
        end
      end

    end
  end

  describe '#stop' do
    before do
      subject.start
    end

    it 'terminates' do
      subject.stop
    end
  end

  describe '#pause' do
    before { subject.start }
    it 'sets paused to true' do
      subject.pause
      expect(subject).to be_paused
    end
  end

  describe '#unpause' do
    before do
      subject.start
      subject.pause
    end

    it 'sets paused to false' do
      subject.unpause
      expect(subject).to_not be_paused
    end
  end

  describe '#paused?' do
    before { subject.start }
    it 'returns true when paused' do
      subject.paused = true
      expect(subject).to be_paused
    end
    it 'returns false when not paused (nil)' do
      subject.paused = nil
      expect(subject).not_to be_paused
    end
    it 'returns false when not paused (false)' do
      subject.paused = false
      expect(subject).not_to be_paused
    end
  end

  describe '#listen?' do
    context 'when processing' do
      before { subject.start }
      it { should be_processing }
    end

    context 'when stopped' do
      it { should_not be_processing }
    end

    context 'when paused' do
      before do
        subject.start
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
        expect(silencer).to receive(:configure).once.with(ignore: [/bar/])

        subject

        expect(silencer).to receive(:configure).once.
          with(ignore: [/bar/, /foo/])

        subject.ignore(/foo/)
      end
    end

    context 'with existing ignore options (array)' do
      let(:options) { { ignore: [/bar/] } }

      it 'adds up to existing ignore options' do
        expect(silencer).to receive(:configure).once.with(ignore: [/bar/])

        subject

        expect(silencer).to receive(:configure).once.
          with(ignore: [/bar/, /foo/])

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
        expect(silencer).to receive(:configure).once.with(ignore!: [/bar/])
        subject
        expect(silencer).to receive(:configure).once.with(ignore!: [/foo/])
        subject.ignore!([/foo/])
      end
    end

    context 'with existing ignore options' do
      let(:options) { { ignore: /bar/ } }

      it 'deletes ignore options' do
        expect(silencer).to receive(:configure).once.with(ignore: [/bar/])
        subject
        expect(silencer).to receive(:configure).once.with(ignore!: [/foo/])
        subject.ignore!([/foo/])
      end
    end
  end

  describe '#only' do
    context 'with existing only options' do
      let(:options) { { only: /bar/ } }

      it 'overwrites existing ignore options' do
        expect(silencer).to receive(:configure).once.with(only: [/bar/])
        subject
        expect(silencer).to receive(:configure).once.with(only: [/foo/])
        subject.only([/foo/])
      end
    end
  end

  describe 'processing changes' do
    # TODO: this is an event processer test
    it 'gets two changes and calls the block once' do
      allow(silencer).to receive(:silenced?) { false }

      subject.block = proc do |modified, added, _|
        expect(modified).to eql(['foo/bar.txt'])
        expect(added).to eql(['foo/baz.txt'])
      end

      dir = instance_double(Pathname, children: %w(bar.txt baz.txt))

      allow(queue).to receive(:<<)

      subject.start
      subject.queue(:file, :modified, dir, 'bar.txt', {})
      subject.queue(:file, :added, dir, 'baz.txt', {})
      subject.block.call(['foo/bar.txt'], ['foo/baz.txt'], [])
    end
  end

  context 'when listener is stopped' do
    before do
      subject.stop
      allow(silencer).to receive(:silenced?) { true }
    end

    it 'queuing does not crash when changes come in' do
      expect do
        # TODO: write directly to queue
        subject.send(
          :_queue_raw_change,
          :dir,
          realdir1,
          'path',
          recursive: true)

      end.to_not raise_error
    end
  end
end
