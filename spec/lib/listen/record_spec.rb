require 'spec_helper'

describe Listen::Record do
  let(:registry) { instance_double(Celluloid::Registry) }

  let(:listener) do
    instance_double(Listen::Listener, registry: registry, options: {})
  end

  let(:record) { Listen::Record.new(listener) }
  let(:dir) { instance_double(Pathname, to_s: '/dir') }

  describe '#update_file' do
    context 'with path in watched dir' do
      it 'sets path by spliting dirname and basename' do
        record.update_file(dir, 'file.rb', mtime: 1.1)
        expect(record.paths['/dir']).to eq('file.rb' => { mtime: 1.1 })
      end

      it 'sets path and keeps old data not overwritten' do
        record.update_file(dir, 'file.rb', foo: 1, bar: 2)
        record.update_file(dir, 'file.rb', foo: 3)
        watched_dir = record.paths['/dir']
        expect(watched_dir).to eq('file.rb' => { foo: 3, bar: 2 })
      end
    end

    context 'with subdir path' do
      it 'sets path by spliting dirname and basename' do
        record.update_file(dir, 'path/file.rb', mtime: 1.1)
        expect(record.paths['/dir']['path']).to eq('file.rb' => { mtime: 1.1 })
      end

      it 'sets path and keeps old data not overwritten' do
        record.update_file(dir, 'path/file.rb', foo: 1, bar: 2)
        record.update_file(dir, 'path/file.rb', foo: 3)
        file_data = record.paths['/dir']['path']['file.rb']
        expect(file_data).to eq(foo: 3, bar: 2)
      end
    end
  end

  describe '#add_dir' do
    it 'sets itself when .' do
      record.add_dir(dir, '.')
      expect(record.paths['/dir']).to eq({})
    end

    it 'sets itself when nil' do
      record.add_dir(dir, nil)
      expect(record.paths['/dir']).to eq({})
    end

    it 'sets itself when empty' do
      record.add_dir(dir, '')
      expect(record.paths['/dir']).to eq({})
    end

    it 'correctly sets new directory data' do
      record.add_dir(dir, 'path/subdir')
      expect(record.paths['/dir']).to eq('path/subdir' => {})
    end

    it 'sets path and keeps old data not overwritten' do
      record.add_dir(dir, 'path/subdir')
      record.update_file(dir, 'path/subdir/file.rb', mtime: 1.1)
      record.add_dir(dir, 'path/subdir')
      record.update_file(dir, 'path/subdir/file2.rb', mtime: 1.2)
      record.add_dir(dir, 'path/subdir')

      watched = record.paths['/dir']
      expect(watched.keys).to eq ['path/subdir']
      expect(watched['path/subdir'].keys).to eq %w(file.rb file2.rb)

      subdir = watched['path/subdir']
      expect(subdir['file.rb']).to eq(mtime: 1.1)
      expect(subdir['file2.rb']).to eq(mtime: 1.2)
    end
  end

  describe '#unset_path' do
    context 'path is present' do
      before { record.update_file(dir, 'path/file.rb', mtime: 1.1) }

      it 'unsets path' do
        record.unset_path(dir, 'path/file.rb')
        expect(record.paths).to eq('/dir' => { 'path' => {} })
      end
    end

    context 'path not present' do
      it 'unsets path' do
        record.unset_path(dir, 'path/file.rb')
        expect(record.paths).to eq('/dir' => { 'path' => {} })
      end
    end
  end

  describe '#file_data' do
    context 'with path in watched dir' do
      context 'when path is present' do
        before { record.update_file(dir, 'file.rb', mtime: 1.1) }

        it 'returns file data' do
          expect(record.file_data(dir, 'file.rb')).to eq(mtime: 1.1)
        end
      end

      context 'path not present' do
        it 'return empty hash' do
          expect(record.file_data(dir, 'file.rb')).to be_empty
        end
      end
    end

    context 'with path in subdir' do
      context 'when path is present' do
        before { record.update_file(dir, 'path/file.rb', mtime: 1.1) }

        it 'returns file data' do
          expected = { mtime: 1.1 }
          expect(record.file_data(dir, 'path/file.rb')).to eq expected
        end
      end

      context 'path not present' do
        it 'return empty hash' do
          expect(record.file_data(dir, 'path/file.rb')).to be_empty
        end
      end
    end
  end

  describe '#dir_entries' do
    context 'in watched dir' do
      subject { record.dir_entries(dir, '.') }

      context 'with no entries' do
        it { should be_empty }
      end

      context 'with file.rb in record' do
        before { record.update_file(dir, 'file.rb', mtime: 1.1) }
        it { should eq('file.rb' => { mtime: 1.1 }) }
        context 'when file is removed' do
          before { record.update_file(dir, 'file.rb', mtime: 1.1) }
        end
      end

      context 'with subdir/file.rb in record' do
        before { record.update_file(dir, 'subdir/file.rb', mtime: 1.1) }
        it { should eq('subdir' => {}) }
      end
    end

    context 'in subdir /path' do
      subject { record.dir_entries(dir, 'path') }

      context 'with no entries' do
        it { should be_empty }
      end

      context 'with path/file.rb already in record' do
        before { record.update_file(dir, 'path/file.rb', mtime: 1.1) }
        it { should eq('file.rb' => { mtime: 1.1 }) }
      end
    end
  end

  describe '#build' do
    let(:dir1) { Pathname('/dir1') }
    let(:dir2) { Pathname('/dir2') }

    let(:directories) { [dir1, dir2]  }

    let(:actor) do
      instance_double(Listen::Change, change: nil, terminate: true)
    end

    before do
      allow(listener).to receive(:directories) { directories }
      allow(listener).to receive(:async).with(:change_pool) { actor }
    end

    it 're-inits paths' do
      record.update_file(dir, 'path/file.rb', mtime: 1.1)
      record.build
      expect(record.paths).to eq('/dir1' => {}, '/dir2' => {})
      expect(record.file_data(dir, 'path/file.rb')).to be_empty
    end

    it 'calls change asynchronously on all directories to build record'  do
      expect(actor).to receive(:change).
        with(:dir, dir1, '.', recursive: true, silence: true, build: true)

      expect(actor).to receive(:change).
        with(:dir, dir2, '.', recursive: true, silence: true, build: true)
      record.build
    end
  end

  describe '#still_building!' do
    let(:directories) { [Pathname('/dir_path')] }

    let(:actor) do
      instance_double(Listen::Change, change: nil, terminate: true)
    end

    before do
      allow(listener).to receive(:directories) { directories }
      allow(listener).to receive(:async).with(:change_pool) { actor }
    end

    it 'keeps the build blocking longer' do
      record # To avoid initializing record in thread

      th = Thread.new do
        10.times do
          sleep 0.05
          record.still_building!
        end
      end

      started = Time.now
      record.build
      ended  = Time.now

      th.join

      expect(ended - started).to be > 0.5
    end
  end
end
