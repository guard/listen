# frozen_string_literal: true

RSpec.describe Listen::QueueOptimizer do
  let(:config) { instance_double(Listen::QueueOptimizer::Config) }
  subject { described_class.new(config) }

  # watched dir
  let(:dir) { fake_path('dir') }

  # files
  let(:foo) { fake_path('foo') }
  let(:bar) { fake_path('bar') }
  let(:ignored) { fake_path('ignored') }

  before do
    allow(config).to receive(:debug)

    allow(dir).to receive(:+).with('foo') { foo }
    allow(dir).to receive(:+).with('bar') { bar }
    allow(dir).to receive(:+).with('ignored') { ignored }

    allow(config).to receive(:silenced?).
      with(Pathname('ignored'), :file) { true }

    allow(config).to receive(:silenced?).
      with(Pathname('foo'), :file) { false }

    allow(config).to receive(:silenced?).
      with(Pathname('bar'), :file) { false }

    allow(config).to receive(:exist?).with(foo).and_return(true)
    allow(config).to receive(:exist?).with(bar).and_return(true)
    allow(config).to receive(:exist?).with(ignored).and_return(true)
  end

  describe 'smoosh_changes' do
    subject { described_class.new(config).smoosh_changes(changes) }

    context 'with rename from temp file' do
      let(:changes) do
        [
          [:file, :modified, dir, 'foo'],
          [:file, :removed, dir, 'foo'],
          [:file, :added, dir, 'foo'],
          [:file, :modified, dir, 'foo']
        ]
      end
      it { is_expected.to eq(modified: ['foo'], added: [], removed: []) }
    end

    context 'with a detected temp file' do
      before { allow(config).to receive(:exist?).with(foo).and_return(false) }

      let(:changes) do
        [
          [:file, :added, dir, 'foo'],
          [:file, :modified, dir, 'foo'],
          [:file, :removed, dir, 'foo'],
          [:file, :modified, dir, 'foo']
        ]
      end
      it { is_expected.to eq(modified: [], added: [], removed: []) }
    end

    # e.g. "mv foo x && mv x foo" is like "touch foo"
    context 'when double move' do
      let(:changes) do
        [
          [:file, :removed, dir, 'foo'],
          [:file, :added, dir, 'foo']
        ]
      end
      it { is_expected.to eq(modified: ['foo'], added: [], removed: []) }
    end

    context 'with cookie' do
      context 'when single moved' do
        let(:changes) { [[:file, :moved_to, dir, 'foo', { cookie: 4321 }]] }
        it { is_expected.to eq(modified: [], added: ['foo'], removed: []) }
      end

      context 'when related moved_to' do
        let(:changes) do
          [
            [:file, :moved_from, dir, 'foo', { cookie: 4321 }],
            [:file, :moved_to, dir, 'bar', { cookie: 4321 }]
          ]
        end
        it { is_expected.to eq(modified: [], added: ['bar'], removed: []) }
      end

      # Scenario with workaround for editors using rename()
      context 'when related moved_to with ignored moved_from' do
        let(:changes) do
          [
            [:file, :moved_from, dir, 'ignored', { cookie: 4321 }],
            [:file, :moved_to, dir, 'foo', { cookie: 4321 }]
          ]
        end
        it { is_expected.to eq(modified: ['foo'], added: [], removed: []) }
      end
    end

    context 'with no cookie' do
      context 'with ignored file' do
        let(:changes) { [[:file, :modified, dir, 'ignored']] }
        it { is_expected.to eq(modified: [], added: [], removed: []) }
      end
    end
  end
end
