# frozen_string_literal: true

require 'listen/adapter/config'

RSpec.describe Listen::Adapter::Config do
  let(:directories) { [path1, path2] }
  let(:queue) { instance_double(Queue) }
  let(:silencer) { instance_double(Listen::Silencer) }

  # NOTE: defaults are handled later in Listen::Options
  let(:adapter_options) { { latency: 1.234 } }

  subject do
    described_class.new(directories, queue, silencer, adapter_options)
  end

  # Here's what may be  passed to initializer
  let(:path1) { fake_path('/real/path1', realpath: real_path1) }
  let(:path2) { fake_path('/real/path2', realpath: real_path2) }
  let(:path3) { fake_path('/real/path3', realpath: real_path3) }

  let(:current_path) do
    fake_path('/real/current_path', realpath: real_current_path)
  end

  let(:symlinked_dir1) { fake_path('symlinked_dir1', realpath: real_path1) }
  let(:symlinked_dir2) { fake_path('symlinked_dir1', realpath: real_path2) }

  # Here's what expected to be returned (just so that realpath() calls return
  # something useful)
  let(:real_path1) { fake_path('/real/path1') }
  let(:real_path2) { fake_path('/real/path2') }
  let(:real_path3) { fake_path('/real/path3', directory?: false) }
  let(:real_current_path) { fake_path('/real/current_path') }

  before do
    allow(Pathname).to receive(:new) do |*args|
      fail "unstubbed Pathname.new(#{args.map(&:inspect) * ','})"
    end

    allow(Pathname).to receive(:new).with('/real/path1').and_return(path1)
    allow(Pathname).to receive(:new).with('/real/path2').and_return(path2)
    allow(Pathname).to receive(:new).with('/real/path3').and_return(path3)

    allow(Pathname).to receive(:new).with(path1).and_return(path1)
    allow(Pathname).to receive(:new).with(path2).and_return(path2)

    allow(Pathname).to receive(:new).with('symlinked_dir1').
      and_return(symlinked_dir1)

    allow(Pathname).to receive(:new).with('symlinked_dir2').
      and_return(symlinked_dir2)

    allow(Dir).to receive(:pwd).and_return('/real/current_path')

    allow(Pathname).to receive(:new).
      with('/real/current_path').and_return(current_path)
  end

  describe '#initialize' do
    context 'with directories as array' do
      context 'with strings for directories' do
        context 'when already resolved' do
          let(:directories) { ['/real/path1', '/real/path2'] }
          it 'returns array of pathnames' do
            expect(subject.directories).to eq([real_path1, real_path2])
          end
        end

        context 'when not resolved' do
          let(:directories) { %w[symlinked_dir1 symlinked_dir2] }
          it 'returns array of resolved pathnames' do
            expect(subject.directories).to eq([real_path1, real_path2])
          end
        end
      end

      context 'with Pathnames for directories' do
        let(:directories) { [path1, path2] }
        it 'returns array of pathnames' do
          expect(subject.directories).to eq([real_path1, real_path2])
        end
      end
    end

    context 'with directories as messy array' do
      pending 'implement me'
    end

    context 'with no directories' do
      let(:directories) { }
      it 'returns the current path in array' do
        expect(subject.directories).to eq([real_current_path])
      end
    end

    context 'with file path' do
      let(:directories) { ['/real/path3'] }
      it 'raises argument error requesting a directory' do
        expect { subject }.to raise_error(ArgumentError, /must be a directory/)
      end
    end
  end

  describe '#adapter_options' do
    it 'provides a set of adapter_specific options' do
      expect(subject.adapter_options).to eq(latency: 1.234)
    end
  end

  describe '#queue' do
    it 'provides a direct queue for filesystem events' do
      expect(subject.queue).to eq(queue)
    end
  end

  describe '#silencer' do
    it 'provides a silencer object' do
      expect(subject.silencer).to eq(silencer)
    end
  end
end
