# This is just so stubs work
require 'rb-fsevent'

require 'listen/adapter/darwin'

include Listen

RSpec.describe Adapter::Darwin do
  describe 'class' do
    subject { described_class }

    if darwin?
      it { should be_usable }
    else
      it { should_not be_usable }
    end
  end

  let(:options) { {} }
  let(:config) { instance_double(Listen::Adapter::Config) }
  let(:queue) { instance_double(::Queue) }
  let(:silencer) { instance_double(Listen::Silencer) }

  let(:dir1) { fake_path('/foo/dir1', cleanpath: fake_path('/foo/dir1')) }
  let(:directories) { [dir1] }

  subject { described_class.new(config) }

  before do
    allow(config).to receive(:directories).and_return(directories)
    allow(config).to receive(:adapter_options).and_return(options)
  end

  describe '#_latency' do
    subject { described_class.new(config).options.latency }

    context 'with no overriding option' do
      it { should eq 0.1 }
    end

    context 'with custom latency overriding' do
      let(:options) { { latency: 1234 } }
      it { should eq 1234 }
    end
  end

  describe 'multiple dirs' do
    let(:dir1) { fake_path('/foo/dir1', cleanpath: fake_path('/foo/dir1')) }
    let(:dir2) { fake_path('/foo/dir2', cleanpath: fake_path('/foo/dir1')) }
    let(:dir3) { fake_path('/foo/dir3', cleanpath: fake_path('/foo/dir1')) }

    before do
      allow(config).to receive(:queue).and_return(queue)
      allow(config).to receive(:silencer).and_return(silencer)
    end

    let(:foo1) { double('fsevent1') }
    let(:foo2) { double('fsevent2') }
    let(:foo3) { double('fsevent3') }

    before do
      allow(FSEvent).to receive(:new).and_return(*expectations.values, nil)
      expectations.each do |dir, obj|
        allow(obj).to receive(:watch).with(dir.to_s, latency: 0.1)
      end
      subject.configure
    end

    describe 'configuration' do
      context 'with 1 directory' do
        let(:directories) { expectations.keys.map { |p| Pathname(p.to_s) } }

        let(:expectations) { { '/foo/dir1': foo1 } }

        it 'configures directory' do
          expect(foo1).to have_received(:watch).with('/foo/dir1', latency: 0.1)
        end
      end

      context 'with 2 directories' do
        let(:directories) { expectations.keys.map { |p| Pathname(p.to_s) } }
        let(:expectations) { { dir1: foo1, dir2: foo2 } }

        it 'configures directories' do
          expect(foo1).to have_received(:watch).with('dir1', latency: 0.1)
          expect(foo2).to have_received(:watch).with('dir2', latency: 0.1)
        end
      end

      context 'with 3 directories' do
        let(:directories) { expectations.keys.map { |p| Pathname(p.to_s) } }
        let(:expectations) do
          {
            '/foo/dir1': foo1,
            '/foo/dir2': foo2,
            '/foo/dir3': foo3
          }
        end

        it 'configures directories' do
          expect(foo1).to have_received(:watch).with('/foo/dir1', latency: 0.1)
          expect(foo2).to have_received(:watch).with('/foo/dir2', latency: 0.1)
          expect(foo3).to have_received(:watch).with('/foo/dir3', latency: 0.1)
        end
      end
    end

    describe 'running threads' do
      let(:running) { [] }
      let(:directories) { expectations.keys.map { |p| Pathname(p.to_s) } }

      before do
        started = ::Queue.new
        threads = ::Queue.new
        left = ::Queue.new

        # NOTE: Travis has a hard time creating threads on OSX
        thread_start_overhead = 3
        max_test_time = 3 * thread_start_overhead
        block_time = max_test_time + thread_start_overhead

        expectations.each do |name, _|
          left << name
        end

        expectations.each do |_, obj|
          allow(obj).to receive(:run) do
            current_name = left.pop
            threads << Thread.current
            started << current_name
            sleep block_time
          end
        end

        Timeout.timeout(max_test_time) do
          subject.start
          until started.size == expectations.size
            sleep 0.1
          end
        end

        running << started.pop until started.empty?

        killed = ::Queue.new
        killed << threads.pop.kill until threads.empty?
        killed.pop.join until killed.empty?
      end

      context 'with 1 directory' do
        let(:expectations) { { dir1: foo1 } }
        it 'runs all the workers without blocking' do
          expect(running.sort).to eq(expectations.keys)
        end
      end

      context 'with 2 directories' do
        let(:expectations) { { dir1: foo1, dir2: foo2 } }
        it 'runs all the workers without blocking' do
          expect(running.sort).to eq(expectations.keys)
        end
      end

      context 'with 3 directories' do
        let(:expectations) { { dir1: foo1, dir2: foo2, dir3: foo3 } }
        it 'runs all the workers without blocking' do
          expect(running.sort).to eq(expectations.keys)
        end
      end
    end
  end
end
