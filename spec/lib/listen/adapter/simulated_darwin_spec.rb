RSpec.describe Listen::Adapter::SimulatedDarwin::FakeEvent do
  subject do
    described_class.new(watched_dir, event)
  end

  let(:watched_dir) { Pathname('/foo') }
  let(:event) do
    double('event',
           name: item,
           watcher: double('watcher', path: '/foo/dir'),
           flags: flags
          )
  end

  describe '#dir' do
    context 'when a file is given' do
      let(:item) { 'file.txt' }
      let(:flags) { [] }
      it 'is the containing dir' do
        expect(subject.dir).to eq('/foo/dir/')
      end
    end

    context 'when a dir is given' do
      let(:item) { 'dir1' }
      let(:flags) { [:isdir] }
      it 'is the containing dir' do
        expect(subject.dir).to eq('/foo/dir/')
      end
    end
  end

  # For debugging only
  describe '#real_path' do
    let(:item) { 'file.txt' }
    let(:flags) { [] }
    it 'is the path of the changed file relative to watched dir' do
      expect(subject.real_path).to eq('dir/file.txt')
    end
  end
end

RSpec.describe Listen::Adapter::SimulatedDarwin do
  describe 'class' do
    subject { described_class }
    if linux?
      if /1|true/ =~ ENV['LISTEN_GEM_SIMULATE_FSEVENT']
        it { should be_usable }
      else
        it { should_not be_usable }
      end
    else
      it { should_not be_usable }
    end
  end
end
