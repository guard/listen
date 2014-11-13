require 'spec_helper'

# This is just so stubs work
require 'rb-fsevent'

require 'listen/adapter/darwin'

include Listen

describe Adapter::Darwin do
  describe 'class' do
    subject { described_class }
    it { should be_local_fs }

    if darwin?
      it { should be_usable }
    else
      it { should_not be_usable }
    end
  end

  let(:options) { {} }
  let(:mq) { instance_double(Listener, options: options) }

  describe '#_latency' do
    subject do
      adapter = described_class.new(options.merge(mq: mq, directories: []))
      adapter.options.latency
    end

    context 'with no overriding option' do
      it { should eq 0.1 }
    end

    context 'with custom latency overriding' do
      let(:options) { { latency: 1234 } }
      it { should eq 1234 }
    end
  end

  describe 'multiple dirs' do
    subject do
      dirs = config.keys.map { |p| Pathname(p.to_s) }
      described_class.new(directories: dirs)
    end

    let(:foo1) { double('foo1') }
    let(:foo2) { double('foo2') }
    let(:foo3) { double('foo3') }

    before do
      allow(FSEvent).to receive(:new).and_return(*config.values, nil)
      config.each do |dir, obj|
        allow(obj).to receive(:watch).with(dir.to_s, latency: 0.1)
      end
      subject.configure
    end

    describe 'configuration' do
      context 'with 1 directory' do
        let(:config) { { dir1: foo1 } }

        it 'configures directory' do
          expect(foo1).to have_received(:watch).with('dir1', latency: 0.1)
        end
      end

      context 'with 2 directories' do
        let(:config) { { dir1: foo1, dir2: foo2 } }

        it 'configures directories' do
          expect(foo1).to have_received(:watch).with('dir1', latency: 0.1)
          expect(foo2).to have_received(:watch).with('dir2', latency: 0.1)
        end
      end

      context 'with 3 directories' do
        let(:config) { { dir1: foo1, dir2: foo2, dir3: foo3 } }

        it 'configures directories' do
          expect(foo1).to have_received(:watch).with('dir1', latency: 0.1)
          expect(foo2).to have_received(:watch).with('dir2', latency: 0.1)
          expect(foo3).to have_received(:watch).with('dir3', latency: 0.1)
        end
      end
    end

    describe 'running threads' do
      let(:running) { [] }

      before do
        started = Queue.new
        threads = Queue.new
        left = Queue.new

        # NOTE: Travis has a hard time creating threads on OSX
        thread_start_overhead = 3
        max_test_time = 3 * thread_start_overhead
        block_time = max_test_time + thread_start_overhead

        config.each do |name, obj|
          left << name # anything, we're just counting
          allow(obj).to receive(:run).once do
            threads << Thread.current
            started << name
            left.pop
            sleep block_time
          end
        end

        Timeout.timeout(max_test_time) do
          subject.start
          running << started.pop until left.empty?
        end

        running << started.pop until started.empty?

        killed = Queue.new
        killed << threads.pop.kill until threads.empty?
        killed.pop.join until killed.empty?
      end

      context 'with 1 directory' do
        let(:config) { { dir1: foo1 } }
        it 'runs all the workers without blocking' do
          expect(running.sort).to eq(config.keys)
        end
      end

      context 'with 2 directories' do
        let(:config) { { dir1: foo1, dir2: foo2 } }
        it 'runs all the workers without blocking' do
          expect(running.sort).to eq(config.keys)
        end
      end

      context 'with 3 directories' do
        let(:config) { { dir1: foo1, dir2: foo2, dir3: foo3 } }
        it 'runs all the workers without blocking' do
          expect(running.sort).to eq(config.keys)
        end
      end
    end
  end
end
