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
    context 'within watched dir' do
      context 'when path is present' do
        before { record.update_file(dir, 'file.rb', mtime: 1.1) }

        it 'unsets path' do
          record.unset_path(dir, 'file.rb')
          expect(record.paths).to eq('/dir' => {})
        end
      end

      context 'when path not present' do
        it 'unsets path' do
          record.unset_path(dir, 'file.rb')
          expect(record.paths).to eq('/dir' => {})
        end
      end
    end

    context 'within subdir' do
      context 'when path is present' do
        before { record.update_file(dir, 'path/file.rb', mtime: 1.1) }

        it 'unsets path' do
          record.unset_path(dir, 'path/file.rb')
          expect(record.paths).to eq('/dir' => { 'path' => {} })
        end
      end

      context 'when path not present' do
        it 'unsets path' do
          record.unset_path(dir, 'path/file.rb')
          expect(record.paths).to eq('/dir' => {})
        end
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

    before do
      allow(listener).to receive(:directories) { directories }

      allow(::File).to receive(:lstat) do |path|
        fail "::File.lstat stub called with: #{path.inspect}"
      end

      allow(::Dir).to receive(:entries) do |path|
        fail "::Dir.entries stub called with: #{path.inspect}"
      end

      allow(::Dir).to receive(:exist?) do |path|
        fail "::Dir.exist? stub called with: #{path.inspect}"
      end
    end

    it 're-inits paths' do
      allow(::Dir).to receive(:entries) { [] }

      record.update_file(dir, 'path/file.rb', mtime: 1.1)
      record.build
      expect(record.paths).to eq('/dir1' => {}, '/dir2' => {})
      expect(record.file_data(dir, 'path/file.rb')).to be_empty
    end

    let(:foo_stat) { instance_double(::File::Stat, mtime: 1.0, mode: 0644) }
    let(:bar_stat) { instance_double(::File::Stat, mtime: 2.3, mode: 0755) }

    context 'with no subdirs' do

      before do
        expect(::Dir).to receive(:entries).with('/dir1/.') { %w(foo bar) }
        expect(::Dir).to receive(:exist?).with('/dir1/./foo') { false }
        expect(::Dir).to receive(:exist?).with('/dir1/./bar') { false }
        expect(::File).to receive(:lstat).with('/dir1/./foo') { foo_stat }
        expect(::File).to receive(:lstat).with('/dir1/./bar') { bar_stat }

        expect(::Dir).to receive(:entries).with('/dir2/.') { [] }
      end

      it 'builds record'  do
        record.build
        expect(record.paths.keys).to eq %w( /dir1 /dir2 )
        expect(record.paths['/dir1']).
          to eq(
            'foo' => { mtime: 1.0, mode: 0644 },
            'bar' => { mtime: 2.3, mode: 0755 })
      end
    end

    context 'with subdir containing files' do
      before do
        expect(::Dir).to receive(:entries).with('/dir1/.') { %w(foo) }
        expect(::Dir).to receive(:exist?).with('/dir1/./foo') { true }

        expect(::Dir).to receive(:entries).with('/dir1/foo') { %w(bar) }

        expect(::Dir).to receive(:exist?).with('/dir1/foo/bar') { false }
        expect(::File).to receive(:lstat).with('/dir1/foo/bar') { bar_stat }

        expect(::Dir).to receive(:entries).with('/dir2/.') { [] }
      end

      it 'builds record'  do
        record.build
        expect(record.paths.keys).to eq %w( /dir1 /dir2 )
        expect(record.paths['/dir1']).
          to eq('foo' => { 'bar' => { mtime: 2.3, mode: 0755 } })
        expect(record.paths['/dir2']).to eq({})
      end
    end

    context 'with subdir containing dirs' do
      before do
        expect(::Dir).to receive(:entries).with('/dir1/.') { %w(foo) }
        expect(::Dir).to receive(:exist?).with('/dir1/./foo') { true }

        expect(::Dir).to receive(:entries).with('/dir1/foo') { %w(bar baz) }

        expect(::Dir).to receive(:exist?).with('/dir1/foo/bar') { true }
        expect(::Dir).to receive(:entries).with('/dir1/foo/bar') { [] }

        expect(::Dir).to receive(:exist?).with('/dir1/foo/baz') { true }
        expect(::Dir).to receive(:entries).with('/dir1/foo/baz') { [] }

        expect(::Dir).to receive(:entries).with('/dir2/.') { [] }
      end

      it 'builds record'  do
        record.build
        expect(record.paths.keys).to eq %w( /dir1 /dir2 )
        expect(record.paths['/dir1']).
          to eq(
            'foo' => {},
            'foo/bar' => {},
            'foo/baz' => {},
        )
        expect(record.paths['/dir2']).to eq({})
      end
    end
  end
end
