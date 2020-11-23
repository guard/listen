# frozen_string_literal: true

require 'listen/event/queue'

# TODO: not part of listener really
RSpec.describe Listen::Event::Queue do
  let(:queue) { instance_double(Thread::Queue, 'my queue') }

  let(:config) { instance_double(Listen::Event::Queue::Config) }

  let(:relative) { false }

  subject { described_class.new(config) }

  before do
    allow(config).to receive(:relative?).and_return(relative)
    allow(Thread::Queue).to receive(:new).and_return(queue)
  end

  describe '#empty?' do
    before do
      allow(queue).to receive(:empty?).and_return(empty)
    end

    context 'when empty' do
      let(:empty) { true }
      it { is_expected.to be_empty }
    end

    context 'when not empty' do
      let(:empty) { false }
      let(:watched_dir) { fake_path('watched_dir') }
      before do
        allow(queue).to receive(:empty?).and_return(false)
      end
      it { is_expected.to_not be_empty }
    end
  end

  describe '#pop' do
    before do
      allow(queue).to receive(:pop).and_return('foo')
    end

    context 'when empty' do
      let(:value) { 'foo' }
      it 'forward the call to the queue' do
        expect(subject.pop).to eq('foo')
      end
    end
  end

  describe '#<<' do
    let(:watched_dir) { fake_path('watched_dir') }
    before do
      allow(queue).to receive(:<<)
    end

    context 'when relative option is true' do
      let(:relative) { true }

      context 'when watched dir is the current dir' do
        let(:options) { { relative: true, directories: Pathname.pwd } }

        let(:dir_rel_path) { fake_path('.') }
        let(:foo_rel_path) { fake_path('foo', exist?: true) }

        it 'registers relative paths' do
          allow(dir_rel_path).to receive(:+).with('foo') { foo_rel_path }

          allow(watched_dir).to receive(:relative_path_from).
            with(Pathname.pwd).
            and_return(dir_rel_path)

          expect(queue).to receive(:<<).
            with([:file, :modified, dir_rel_path, 'foo', {}])

          subject.<<([:file, :modified, watched_dir, 'foo', {}])
        end
      end

      context 'when watched dir is not the current dir' do
        let(:options) { { relative: true } }
        let(:dir_rel_path) { fake_path('..') }
        let(:foo_rel_path) { fake_path('../foo', exist?: true) }

        it 'registers relative path' do
          allow(watched_dir).to receive(:relative_path_from).
            with(Pathname.pwd).
            and_return(dir_rel_path)

          expect(queue).to receive(:<<).
            with([:file, :modified, dir_rel_path, 'foo', {}])

          subject.<<([:file, :modified, watched_dir, 'foo', {}])
        end
      end

      context 'when watched dir is on another drive' do
        let(:watched_dir) { fake_path('watched_dir', realpath: 'd:/foo') }
        let(:foo_rel_path) { fake_path('d:/foo', exist?: true) }

        it 'registers full path' do
          allow(watched_dir).to receive(:relative_path_from).
            with(Pathname.pwd).
            and_raise(ArgumentError)

          allow(watched_dir).to receive(:+).with('foo') { foo_rel_path }

          expect(queue).to receive(:<<).
            with([:file, :modified, watched_dir, 'foo', {}])

          subject.<<([:file, :modified, watched_dir, 'foo', {}])
        end
      end
    end
  end
end
