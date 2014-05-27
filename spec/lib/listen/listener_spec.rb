require 'spec_helper'

describe Listen::Listener do
  subject { described_class.new(options) }
  let(:options) { {} }
  let(:registry) { instance_double(Celluloid::Registry, :[]= => true) }

  let(:supervisor) do
    instance_double(Celluloid::SupervisionGroup, add: true, pool: true)
  end

  let(:record) { instance_double(Listen::Record, terminate: true, build: true) }
  let(:silencer) { instance_double(Listen::Silencer, terminate: true) }
  let(:adapter) { instance_double(Listen::Adapter::Base, local_fs?: true) }
  let(:proxy) { instance_double(Celluloid::ActorProxy, terminate: true) }
  let(:change_pool_async) { instance_double(Listen::Change) }
  before do
    allow(Celluloid::Registry).to receive(:new) { registry }
    allow(Celluloid::SupervisionGroup).to receive(:run!) { supervisor }
    allow(registry).to receive(:[]).with(:silencer) { silencer }
    allow(registry).to receive(:[]).with(:adapter) { adapter }
    allow(registry).to receive(:[]).with(:record) { record }
    allow(registry).to receive(:[]).with(:change_pool) { proxy }

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
    context 'default options' do
      it 'sets default options' do
        expect(subject.options).
          to eq(
            debug: false,
            latency: nil,
            wait_for_delay: 0.1,
            force_polling: false,
            polling_fallback_message: nil)
      end
    end

    context 'custom options' do
      subject do
        described_class.new('lib', latency: 1.234, wait_for_delay: 0.85)
      end

      it 'sets new options on initialize' do
        expect(subject.options).
          to eq(
            debug: false,
            latency: 1.234,
            wait_for_delay: 0.85,
            force_polling: false,
            polling_fallback_message: nil)
      end
    end
  end

  describe '#start' do
    before do
      allow(subject).to receive(:_start_adapter)
      allow(silencer).to receive(:silenced?) { false }
    end

    it 'registers silencer' do
      expect(supervisor).to receive(:add).
        with(Listen::Silencer, as: :silencer, args: subject)

      subject.start
    end

    it 'supervises change_pool' do
      expect(supervisor).to receive(:pool).
        with(Listen::Change, as: :change_pool, args: subject)

      subject.start
    end

    it 'supervises adaper' do
      allow(Listen::Adapter).to receive(:select) { Listen::Adapter::Polling }
      expect(supervisor).to receive(:add).
        with(Listen::Adapter::Polling, as: :adapter, args: subject)

      subject.start
    end

    it 'supervises record' do
      expect(supervisor).to receive(:add).
        with(Listen::Record, as: :record, args: subject)

      subject.start
    end

    it 'builds record' do
      expect(record).to receive(:build)
      subject.start
    end

    it 'sets paused to false' do
      subject.start
      expect(subject.paused).to be_falsey
    end

    it 'starts adapter' do
      expect(subject).to receive(:_start_adapter)
      subject.start
    end

    it 'calls block on changes' do
      foo = instance_double(Pathname, to_s: 'foo', exist?: true)

      subject.queue(:file, :modified, foo)
      block_stub = instance_double(Proc)
      subject.block = block_stub
      expect(block_stub).to receive(:call).with(['foo'], [], [])
      subject.start
      sleep 0.25
    end
  end

  describe '#stop' do
    it 'terminates supervisor' do
      subject.supervisor = supervisor
      expect(supervisor).to receive(:terminate)
      subject.stop
    end
  end

  describe '#pause' do
    it 'sets paused to true' do
      subject.pause
      expect(subject.paused).to be_truthy
    end
  end

  describe '#unpause' do
    it 'builds record' do
      expect(record).to receive(:build)
      subject.unpause
    end

    it 'sets paused to false' do
      allow(record).to receive(:build)
      subject.unpause
      expect(subject.paused).to be_falsey
    end
  end

  describe '#paused?' do
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
    it 'returns true when not paused (false)' do
      subject.paused = false
      subject.stopping = false
      expect(subject.listen?).to be_truthy
    end

    it 'returns false when not paused (nil)' do
      subject.paused = nil
      subject.stopping = false
      expect(subject.listen?).to be_falsey
    end

    it 'returns false when paused' do
      subject.paused = true
      subject.stopping = false
      expect(subject.listen?).to be_falsey
    end

    it 'returns false when stopped' do
      subject.paused = false
      subject.stopping = true
      expect(subject.listen?).to be_falsey
    end
  end

  describe '#ignore' do
    let(:new_silencer) { instance_double(Listen::Silencer) }
    before { allow(Celluloid::Actor).to receive(:[]=) }

    it 'resets silencer actor' do
      expect(Listen::Silencer).to receive(:new).with(subject) { new_silencer }
      expect(registry).to receive(:[]=).with(:silencer, new_silencer)
      subject.ignore(/foo/)
    end

    context 'with existing ignore options' do
      let(:options) { { ignore: /bar/ } }

      it 'adds up to existing ignore options' do
        expect(Listen::Silencer).to receive(:new).with(subject)
        subject.ignore(/foo/)
        expect(subject.options).to include(ignore: [/bar/, /foo/])
      end
    end

    context 'with existing ignore options (array)' do
      let(:options) { { ignore: [/bar/] } }

      it 'adds up to existing ignore options' do
        expect(Listen::Silencer).to receive(:new).with(subject)
        subject.ignore(/foo/)
        expect(subject.options).to include(ignore: [[/bar/], /foo/])
      end
    end
  end

  describe '#ignore!' do
    let(:new_silencer) { instance_double(Listen::Silencer) }
    before { allow(Celluloid::Actor).to receive(:[]=) }

    it 'resets silencer actor' do
      expect(Listen::Silencer).to receive(:new).with(subject) { new_silencer }
      expect(registry).to receive(:[]=).with(:silencer, new_silencer)
      subject.ignore!(/foo/)
      expect(subject.options).to include(ignore!: /foo/)
    end

    context 'with existing ignore! options' do
      let(:options) { { ignore!: /bar/ } }

      it 'overwrites existing ignore options' do
        expect(Listen::Silencer).to receive(:new).with(subject)
        subject.ignore!([/foo/])
        expect(subject.options).to include(ignore!: [/foo/])
      end
    end

    context 'with existing ignore options' do
      let(:options) { { ignore: /bar/ } }

      it 'deletes ignore options' do
        expect(Listen::Silencer).to receive(:new).with(subject)
        subject.ignore!([/foo/])
        expect(subject.options).to_not include(ignore: /bar/)
      end
    end
  end

  describe '#only' do
    let(:new_silencer) { instance_double(Listen::Silencer) }
    before { allow(Celluloid::Actor).to receive(:[]=) }

    it 'resets silencer actor' do
      expect(Listen::Silencer).to receive(:new).with(subject) { new_silencer }
      expect(registry).to receive(:[]=).with(:silencer, new_silencer)
      subject.only(/foo/)
    end

    context 'with existing only options' do
      let(:options) { { only: /bar/ } }

      it 'overwrites existing ignore options' do
        expect(Listen::Silencer).to receive(:new).with(subject)
        subject.only([/foo/])
        expect(subject.options).to include(only: [/foo/])
      end
    end
  end

  describe '_wait_for_changes' do
    it 'gets two changes and calls the block once' do
      allow(silencer).to receive(:silenced?) { false }

      fake_time = 0
      allow(subject).to receive(:sleep) do |sec|
        fake_time += sec
        subject.stopping = true if fake_time > 1
      end

      subject.block = proc do |modified, added, _|
        expect(modified).to eql(['foo.txt'])
        expect(added).to eql(['bar.txt'])
      end

      foo = instance_double(
        Pathname,
        to_s: 'foo.txt',
        exist?: true,
        directory?: false)

      bar = instance_double(
        Pathname,
        to_s: 'bar.txt',
        exist?: true,
        directory?: false)

      subject.queue(:file, :modified, foo, {})
      subject.queue(:file, :added, bar, {})

      subject.send :_wait_for_changes
    end
  end

  describe '_smoosh_changes' do
    it 'recognizes rename from temp file' do
      path = instance_double(
        Pathname,
        to_s: 'foo',
        exist?: true,
        directory?: false)

      changes = [
        [:file, :modified, path],
        [:file, :removed, path],
        [:file, :added, path],
        [:file, :modified, path]
      ]
      allow(silencer).to receive(:silenced?) { false }
      smooshed = subject.send :_smoosh_changes, changes
      expect(smooshed).to eq(modified: ['foo'], added: [], removed: [])
    end

    it 'recognizes deleted temp file' do
      path = instance_double(
        Pathname,
        to_s: 'foo',
        exist?: false,
        directory?: false)

      changes = [
        [:file, :added, path],
        [:file, :modified, path],
        [:file, :removed, path],
        [:file, :modified, path]
      ]
      allow(silencer).to receive(:silenced?) { false }
      smooshed = subject.send :_smoosh_changes, changes
      expect(smooshed).to eq(modified: [], added: [], removed: [])
    end

    it 'recognizes double move as modification' do
      # e.g. "mv foo x && mv x foo" is like "touch foo"
      path = instance_double(
        Pathname,
        to_s: 'foo',
        exist?: true,
        directory?: false)

      changes = [
        [:file, :removed, path],
        [:file, :added, path]
      ]
      allow(silencer).to receive(:silenced?) { false }
      smooshed = subject.send :_smoosh_changes, changes
      expect(smooshed).to eq(modified: ['foo'], added: [], removed: [])
    end

    context 'with cookie' do

      it 'recognizes single moved_to as add' do
        foo = instance_double(
          Pathname,
          to_s: 'foo',
          exist?: true,
          directory?: false)

        changes = [[:file, :moved_to, foo, cookie: 4321]]
        expect(silencer).to receive(:silenced?).with(foo, :file) { false }
        smooshed = subject.send :_smoosh_changes, changes
        expect(smooshed).to eq(modified: [], added: ['foo'], removed: [])
      end

      it 'recognizes related moved_to as add' do
        foo = instance_double(
          Pathname,
          to_s: 'foo',
          exist?: true,
          directory?: false)

        bar = instance_double(
          Pathname,
          to_s: 'bar',
          exist?: true,
          directory?: false)

        changes = [
          [:file, :moved_from, foo , cookie: 4321],
          [:file, :moved_to, bar, cookie: 4321]
        ]

        expect(silencer).to receive(:silenced?).
          twice.with(foo, :file) { false }

        expect(silencer).to receive(:silenced?).with(bar, :file) { false }
        smooshed = subject.send :_smoosh_changes, changes
        expect(smooshed).to eq(modified: [], added: ['bar'], removed: [])
      end

      # Scenario with workaround for editors using rename()
      it 'recognizes related moved_to with ignored moved_from as modify' do

        ignored = instance_double(
          Pathname,
          to_s: 'foo',
          exist?: true,
          directory?: false)

        foo = instance_double(
          Pathname,
          to_s: 'foo',
          exist?: true,
          directory?: false)

        changes = [
          [:file, :moved_from, ignored, cookie: 4321],
          [:file, :moved_to, foo , cookie: 4321]
        ]
        expect(silencer).to receive(:silenced?).with(ignored, :file) { true }
        expect(silencer).to receive(:silenced?).with(foo, :file) { false }
        smooshed = subject.send :_smoosh_changes, changes
        expect(smooshed).to eq(modified: ['foo'], added: [], removed: [])
      end
    end

    context 'with no cookie' do
      it 'recognizes properly ignores files' do
        ignored = instance_double(Pathname, to_s: 'foo', exist?: true)

        changes = [[:file, :modified, ignored]]
        expect(silencer).to receive(:silenced?).with(ignored, :file) { true }
        smooshed = subject.send :_smoosh_changes, changes
        expect(smooshed).to eq(modified: [], added: [], removed: [])
      end
    end
  end
end
