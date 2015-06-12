include Listen

RSpec.describe Listener do
  subject { described_class.new(options) }
  let(:options) { {} }
  let(:registry) { instance_double(Celluloid::Registry) }

  let(:supervisor) do
    instance_double(Celluloid::SupervisionGroup, add: true, pool: true)
  end

  let(:record) { instance_double(Record, terminate: true, build: true) }
  let(:silencer) { instance_double(Silencer, configure: nil) }
  let(:adapter) { instance_double(Adapter::Base, start: nil) }

  before do
    allow(Listen::Silencer).to receive(:new) { silencer }

    allow(Celluloid::Registry).to receive(:new) { registry }
    allow(Celluloid::SupervisionGroup).to receive(:run!) { supervisor }
    allow(registry).to receive(:[]).with(:adapter) { adapter }
    allow(registry).to receive(:[]).with(:record) { record }
  end

  describe 'initialize' do
    it { should_not be_paused }

    context 'with a block' do
      describe 'block' do
        subject { described_class.new('lib', &(proc {})) }
        specify { expect(subject.block).to_not be_nil }
      end
    end

    context 'with directories' do
      describe 'directories' do
        subject { described_class.new('lib', 'spec') }
        expected = %w(lib spec).map { |dir| Pathname.pwd + dir }
        specify { expect(subject.directories).to eq expected }
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
          'lib',
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
      allow(subject).to receive(:_start_adapter)
      allow(silencer).to receive(:silenced?) { false }
    end

    it 'supervises adapter' do
      allow(Adapter).to receive(:select) { Adapter::Polling }
      options = [mq: subject, directories: []]
      expect(supervisor).to receive(:add).
        with(Adapter::Polling, as: :adapter, args: options)

      subject.start
    end

    it 'supervises record' do
      expect(supervisor).to receive(:add).
        with(Record, as: :record, args: subject)

      subject.start
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
      expect(subject).to receive(:_start_adapter)
      subject.start
    end

    it 'calls block on changes' do
      foo = instance_double(Pathname, to_s: 'foo', exist?: true)

      dir = instance_double(Pathname)
      allow(dir).to receive(:+).with('foo') { foo }

      block_stub = instance_double(Proc)
      subject.block = block_stub
      expect(block_stub).to receive(:call).with(['foo'], [], [])
      subject.start
      subject.queue(:file, :modified, dir, 'foo')
      sleep 0.25
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
          sleep 0.25
        end
      end

      context 'when watched dir is on another drive' do
        let(:options) { { relative: true } }

        it 'registers full path' do
          event_dir = instance_double(Pathname)
          foo_rel_path = instance_double(Pathname, to_s: 'd:/foo', exist?: true)

          allow(event_dir).to receive(:relative_path_from).
            with(Pathname.pwd).
            and_raise(ArgumentError)

          allow(event_dir).to receive(:+).with('foo') { foo_rel_path }

          block_stub = instance_double(Proc)
          expect(block_stub).to receive(:call).with(['d:/foo'], [], [])
          subject.block = block_stub

          subject.start
          subject.queue(:file, :modified, event_dir, 'foo')
          sleep 0.25
        end
      end

    end
  end

  describe '#stop' do
    before do
      allow(Celluloid::SupervisionGroup).to receive(:run!) { supervisor }
      subject.start
    end

    it 'terminates supervisor' do
      expect(supervisor).to receive(:terminate)
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
        expect(silencer).to receive(:configure).once.with(ignore: [/bar/, /foo/])
        subject.ignore(/foo/)
      end
    end

    context 'with existing ignore options (array)' do
      let(:options) { { ignore: [/bar/] } }

      it 'adds up to existing ignore options' do
        expect(silencer).to receive(:configure).once.with(ignore: [/bar/])
        subject
        expect(silencer).to receive(:configure).once.with(ignore: [/bar/, /foo/])
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

  describe '_wait_for_changes' do
    it 'gets two changes and calls the block once' do
      allow(silencer).to receive(:silenced?) { false }

      subject.block = proc do |modified, added, _|
        expect(modified).to eql(['foo/bar.txt'])
        expect(added).to eql(['foo/baz.txt'])
      end

      bar = instance_double(
        Pathname,
        to_s: 'foo/bar.txt',
        exist?: true,
        directory?: false)

      baz = instance_double(
        Pathname,
        to_s: 'foo/baz.txt',
        exist?: true,
        directory?: false)

      dir = instance_double(Pathname)
      expect(dir).to receive(:+).with('bar.txt') { bar }
      expect(dir).to receive(:+).with('baz.txt') { baz }

      subject.start
      subject.queue(:file, :modified, dir, 'bar.txt', {})
      subject.queue(:file, :added, dir, 'baz.txt', {})
      sleep 0.25
    end
  end

  context 'when listener is stopped' do
    before do
      subject.stop
    end

    it 'queuing does not crash when changes come in' do
      expect do
        subject.send(:_queue_raw_change, :dir, dir, 'path', recursive: true)
      end.to_not raise_error
    end
  end
end
