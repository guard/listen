RSpec.describe Listen::QueueOptimizer do
  let(:config) { instance_double(Listen::QueueOptimizer::Config) }
  subject { described_class.new(config) }

  before do
    allow(config).to receive(:debug)
  end

  describe '_smoosh_changes' do
    it 'recognizes rename from temp file' do
      bar = instance_double(
        Pathname,
        to_s: 'bar',
        exist?: true,
        directory?: false)

      foo = instance_double(Pathname, to_s: 'foo', children: [])
      allow(foo).to receive(:+).with('bar') { bar }
      allow(config).to receive(:exist?).with(bar).and_return(true)

      changes = [
        [:file, :modified, foo, 'bar'],
        [:file, :removed, foo, 'bar'],
        [:file, :added, foo, 'bar'],
        [:file, :modified, foo, 'bar']
      ]
      allow(config).to receive(:silenced?) { false }
      smooshed = subject.smoosh_changes(changes)
      expect(smooshed).to eq(modified: ['bar'], added: [], removed: [])
    end

    it 'ignores deleted temp file' do
      bar = instance_double(
        Pathname,
        to_s: 'bar',
        exist?: false)

      foo = instance_double(Pathname, to_s: 'foo', children: [])
      allow(foo).to receive(:+).with('bar') { bar }
      allow(config).to receive(:exist?).with(bar).and_return(false)

      changes = [
        [:file, :added, foo, 'bar'],
        [:file, :modified, foo, 'bar'],
        [:file, :removed, foo, 'bar'],
        [:file, :modified, foo, 'bar']
      ]
      allow(config).to receive(:silenced?) { false }
      smooshed = subject.smoosh_changes(changes)
      expect(smooshed).to eq(modified: [], added: [], removed: [])
    end

    it 'recognizes double move as modification' do
      # e.g. "mv foo x && mv x foo" is like "touch foo"
      bar = instance_double(
        Pathname,
        to_s: 'bar',
        exist?: true)

      allow(config).to receive(:exist?).with(bar).and_return(true)
      dir = instance_double(Pathname, to_s: 'foo', children: [])
      allow(dir).to receive(:+).with('bar') { bar }

      changes = [
        [:file, :removed, dir, 'bar'],
        [:file, :added, dir, 'bar']
      ]
      allow(config).to receive(:silenced?) { false }
      smooshed = subject.smoosh_changes(changes)
      expect(smooshed).to eq(modified: ['bar'], added: [], removed: [])
    end

    context 'with cookie' do

      it 'recognizes single moved_to as add' do
        foo = instance_double(
          Pathname,
          to_s: 'foo',
          exist?: true)

        dir = instance_double(Pathname, to_s: 'foo', children: [])
        allow(dir).to receive(:+).with('foo') { foo }
        allow(config).to receive(:exist?).with(foo).and_return(true)

        changes = [[:file, :moved_to, dir, 'foo', cookie: 4321]]
        expect(config).to receive(:silenced?).
          with(Pathname('foo'), :file) { false }

        smooshed = subject.smoosh_changes(changes)
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

        dir = instance_double(Pathname, children: [])
        allow(dir).to receive(:+).with('foo') { foo }
        allow(dir).to receive(:+).with('bar') { bar }
        allow(config).to receive(:exist?).with(foo).and_return(true)
        allow(config).to receive(:exist?).with(bar).and_return(true)

        changes = [
          [:file, :moved_from, dir, 'foo', cookie: 4321],
          [:file, :moved_to, dir, 'bar', cookie: 4321]
        ]

        expect(config).to receive(:silenced?).
          twice.with(Pathname('foo'), :file) { false }

        expect(config).to receive(:silenced?).
          with(Pathname('bar'), :file) { false }

        smooshed = subject.smoosh_changes(changes)
        expect(smooshed).to eq(modified: [], added: ['bar'], removed: [])
      end

      # Scenario with workaround for editors using rename()
      it 'recognizes related moved_to with ignored moved_from as modify' do

        ignored = instance_double(
          Pathname,
          to_s: 'ignored',
          exist?: true,
          directory?: false)

        foo = instance_double(
          Pathname,
          to_s: 'foo',
          exist?: true,
          directory?: false)

        dir = instance_double(Pathname, children: [])
        allow(dir).to receive(:+).with('foo') { foo }
        allow(dir).to receive(:+).with('ignored') { ignored }

        allow(config).to receive(:exist?).with(foo).and_return(true)
        allow(config).to receive(:exist?).with(ignored).and_return(true)

        changes = [
          [:file, :moved_from, dir, 'ignored', cookie: 4321],
          [:file, :moved_to, dir, 'foo', cookie: 4321]
        ]

        expect(config).to receive(:silenced?).
          with(Pathname('ignored'), :file) { true }

        expect(config).to receive(:silenced?).
          with(Pathname('foo'), :file) { false }

        smooshed = subject.smoosh_changes(changes)
        expect(smooshed).to eq(modified: ['foo'], added: [], removed: [])
      end
    end

    context 'with no cookie' do
      context 'with ignored file' do
        let(:dir) { instance_double(Pathname, children: []) }
        let(:ignored) { instance_double(Pathname, to_s: 'foo', exist?: true) }

        before do
          expect(config).to receive(:silenced?).
            with(Pathname('ignored'), :file) { true }

          allow(dir).to receive(:+).with('ignored') { ignored }
        end

        it 'recognizes properly ignores files' do
          changes = [[:file, :modified, dir, 'ignored']]
          smooshed = subject.smoosh_changes(changes)
          expect(smooshed).to eq(modified: [], added: [], removed: [])
        end
      end
    end
  end
end
