# frozen_string_literal: true

RSpec.describe Listen::Record do
  let(:dir) { instance_double(Pathname, to_s: '/dir') }
  let(:silencer_options) { { ignore!: [/\A\.ignored/] } }
  let(:silencer) { Listen::Silencer.new(**silencer_options) }
  let(:record) { Listen::Record.new(dir, silencer) }

  def dir_entries_for(hash)
    hash.each do |dir, entries|
      allow(::Dir).to receive(:entries).with(dir) { entries }
    end
  end

  def real_directory(hash)
    dir_entries_for(hash)
    hash.each do |dir, _|
      realpath(dir)
    end
  end

  def file(path)
    allow(::Dir).to receive(:entries).with(path).and_raise(Errno::ENOTDIR)
    path
  end

  def lstat(path, stat = nil)
    stat ||= instance_double(::File::Stat, mtime: 2.3, mode: 0755, size: 42)
    allow(::File).to receive(:lstat).with(path).and_return(stat)
    stat
  end

  def realpath(path)
    allow(::File).to receive(:realpath).with(path).and_return(path)
    path
  end

  def symlink(hash_or_dir)
    if hash_or_dir.is_a?(String)
      allow(::File).to receive(:realpath).with(hash_or_dir).
        and_return(hash_or_dir)
    else
      hash_or_dir.each do |dir, real_path|
        allow(::File).to receive(:realpath).with(dir).and_return(real_path)
      end
    end
  end

  def record_tree(record)
    record.instance_variable_get(:@tree)
  end

  describe '#update_file' do
    context 'with path in watched dir' do
      it 'sets path by spliting dirname and basename' do
        record.update_file('file.rb', mtime: 1.1)
        expect(record_tree(record)).to eq('file.rb' => { mtime: 1.1 })
      end

      it 'sets path and keeps old data not overwritten' do
        record.update_file('file.rb', foo: 1, bar: 2)
        record.update_file('file.rb', foo: 3)
        watched_dir = record_tree(record)
        expect(watched_dir).to eq('file.rb' => { foo: 3, bar: 2 })
      end
    end

    context 'with subdir path' do
      it 'sets path by spliting dirname and basename' do
        record.update_file('path/file.rb', mtime: 1.1)
        expect(record_tree(record)['path']).to eq('file.rb' => { mtime: 1.1 })
      end

      it 'sets path and keeps old data not overwritten' do
        record.update_file('path/file.rb', foo: 1, bar: 2)
        record.update_file('path/file.rb', foo: 3)
        file_data = record_tree(record)['path']['file.rb']
        expect(file_data).to eq(foo: 3, bar: 2)
      end
    end
  end

  describe '#add_dir' do
    it 'sets itself when .' do
      record.add_dir('.')
      expect(record_tree(record)).to eq({})
    end

    it 'sets itself when nil' do
      record.add_dir(nil)
      expect(record_tree(record)).to eq({})
    end

    it 'sets itself when empty' do
      record.add_dir('')
      expect(record_tree(record)).to eq({})
    end

    it 'correctly sets new directory data' do
      record.add_dir('path/subdir')
      expect(record_tree(record)).to eq('path/subdir' => {})
    end

    it 'sets path and keeps old data not overwritten' do
      record.add_dir('path/subdir')
      record.update_file('path/subdir/file.rb', mtime: 1.1)
      record.add_dir('path/subdir')
      record.update_file('path/subdir/file2.rb', mtime: 1.2)
      record.add_dir('path/subdir')

      watched = record_tree(record)
      expect(watched.keys).to eq ['path/subdir']
      expect(watched['path/subdir'].keys).to eq %w[file.rb file2.rb]

      subdir = watched['path/subdir']
      expect(subdir['file.rb']).to eq(mtime: 1.1)
      expect(subdir['file2.rb']).to eq(mtime: 1.2)
    end
  end

  describe '#unset_path' do
    context 'within watched dir' do
      context 'when path is present' do
        before { record.update_file('file.rb', mtime: 1.1) }

        it 'unsets path' do
          record.unset_path('file.rb')
          expect(record_tree(record)).to eq({})
        end
      end

      context 'when path not present' do
        it 'unsets path' do
          record.unset_path('file.rb')
          expect(record_tree(record)).to eq({})
        end
      end
    end

    context 'within subdir' do
      context 'when path is present' do
        before { record.update_file('path/file.rb', mtime: 1.1) }

        it 'unsets path' do
          record.unset_path('path/file.rb')
          expect(record_tree(record)).to eq('path' => {})
        end
      end

      context 'when path not present' do
        it 'unsets path' do
          record.unset_path('path/file.rb')
          expect(record_tree(record)).to eq({})
        end
      end
    end
  end

  describe '#file_data' do
    context 'with path in watched dir' do
      context 'when path is present' do
        before { record.update_file('file.rb', mtime: 1.1) }

        it 'returns file data' do
          expect(record.file_data('file.rb')).to eq(mtime: 1.1)
        end
      end

      context 'path not present' do
        it 'return empty hash' do
          expect(record.file_data('file.rb')).to be_empty
        end
      end
    end

    context 'with path in subdir' do
      context 'when path is present' do
        before { record.update_file('path/file.rb', mtime: 1.1) }

        it 'returns file data' do
          expected = { mtime: 1.1 }
          expect(record.file_data('path/file.rb')).to eq expected
        end
      end

      context 'path not present' do
        it 'return empty hash' do
          expect(record.file_data('path/file.rb')).to be_empty
        end
      end
    end
  end

  describe '#dir_entries' do
    context 'in watched dir' do
      subject { record.dir_entries('.') }

      context 'with no entries' do
        it { should be_empty }
      end

      context 'with file.rb in record' do
        before { record.update_file('file.rb', mtime: 1.1) }
        it { should eq('file.rb' => { mtime: 1.1 }) }
      end

      context 'with subdir/file.rb in record' do
        before { record.update_file('subdir/file.rb', mtime: 1.1) }
        it { should eq('subdir' => {}) }
      end
    end

    context 'when there is a file with the same name as a dir' do
      subject { record.dir_entries('cypress') }

      before do
        record.update_file('cypress.json', mtime: 1.1)
        record.update_file('cypress/README.md', mtime: 1.2)
        record.update_file('a/b/cypress/d', mtime: 1.3)
        record.update_file('a/b/c/cypress', mtime: 1.3)
      end
      it { should eq('README.md' => { mtime: 1.2 }) }
    end

    context 'when there is a file with a similar name to a dir' do
      subject { record.dir_entries('app') }

      before do
        record.update_file('appspec.yml', mtime: 1.1)
        record.update_file('app/README.md', mtime: 1.2)
        record.update_file('spec/app/foo', mtime: 1.3)
      end
      it { should eq('README.md' => { mtime: 1.2 }) }
    end

    context 'in subdir /path' do
      subject { record.dir_entries('path') }

      context 'with no entries' do
        it { should be_empty }
      end

      context 'with path/file.rb already in record' do
        before { record.update_file('path/file.rb', mtime: 1.1) }
        it { should eq('file.rb' => { mtime: 1.1 }) }
      end

      context 'with empty path/subdir' do
        before { record.add_dir('path/subdir') }
        it { should be_empty }
      end

      context 'with path/subdir with file' do
        before do
          record.add_dir('path/subdir')
          record.update_file('path/subdir/file.rb', mtime: 1.1)
        end
        it { should be_empty }
      end
    end
  end

  describe '#build' do
    let(:dir1) { Pathname('/dir1') }

    before do
      stubs = {
        ::File => %w[lstat realpath],
        ::Dir => %w[entries exist?]
      }

      stubs.each do |klass, meths|
        meths.each do |meth|
          allow(klass).to receive(meth.to_sym) do |*args|
            fail "stub called: #{klass}.#{meth}(#{args.map(&:inspect) * ', '})"
          end
        end
      end
    end

    it 're-inits paths' do
      real_directory('/dir1' => [])
      real_directory('/dir' => [])

      record.update_file('path/file.rb', mtime: 1.1)
      record.build
      expect(record_tree(record)).to eq({})
      expect(record.file_data('path/file.rb')).to be_empty
    end

    let(:foo_stat) { instance_double(::File::Stat, mtime: 1.0, mode: 0644, size: 42) }
    let(:bar_stat) { instance_double(::File::Stat, mtime: 2.3, mode: 0755, size: 42) }

    context 'with no subdirs' do
      before do
        real_directory('/dir' => %w[foo bar])
        lstat(file('/dir/foo'), foo_stat)
        lstat(file('/dir/bar'), bar_stat)
        real_directory('/dir2' => [])
      end

      it 'builds record' do
        record.build
        expect(record_tree(record)).
          to eq(
            'foo' => { mtime: 1.0, mode: 0644, size: 42 },
            'bar' => { mtime: 2.3, mode: 0755, size: 42 })
      end
    end

    context 'with subdir containing files' do
      before do
        real_directory('/dir' => %w[dir1 dir2 .ignored])
        real_directory('/dir/dir1' => %w[foo])
        real_directory('/dir/dir1/foo' => %w[bar])
        lstat(file('/dir/.ignored/FETCH_HEAD'))
        lstat(file('/dir/dir1/foo/bar'))
        real_directory('/dir/dir2' => [])
      end

      it 'builds record, skipping silenced patterns' do
        record.build
        expect(record_tree(record)).
          to eq(
            'dir1' => {},
            'dir1/foo' => { 'bar' => { mtime: 2.3, mode: 0755, size: 42 } },
            'dir2' => {}
          )
      end
    end

    context 'with subdir containing dirs' do
      before do
        real_directory('/dir' => %w[dir1 dir2 .ignored])
        real_directory('/dir/.ignored' => %w[ignored_file])
        real_directory('/dir/dir1' => %w[foo])
        real_directory('/dir/dir1/foo' => %w[bar baz])
        real_directory('/dir/dir1/foo/bar' => [])
        real_directory('/dir/dir1/foo/baz' => [])
        real_directory('/dir/dir2' => [])

        allow(::File).to receive(:realpath) { |path| path }
      end

      it 'builds record' do
        record.build
        expect(record_tree(record)).
          to eq(
            'dir1' => {},
            'dir1/foo' => {},
            'dir1/foo/bar' => {},
            'dir1/foo/baz' => {},
            'dir2' => {}
          )
      end
    end

    context 'with subdir containing symlink to parent' do
      subject { record.paths }
      before do
        real_directory('/dir' => %w[dir1 dir2])
        real_directory('/dir/dir1' => %w[foo])
        dir_entries_for('/dir/dir1/foo' => %w[dir1])
        symlink('/dir/dir1/foo' => '/dir/dir1')

        real_directory('/dir/dir2' => [])
      end

      it 'shows a warning' do
        expect_any_instance_of(Listen::Record::SymlinkDetector).to receive(:warn).
          with(/directory is already being watched/)

        record.build
        # expect { record.build }.
        # to raise_error(RuntimeError, /Failed due to looped symlinks/)
      end
    end

    context 'with a normal symlinked directory to another' do
      subject { record.paths }

      before do
        real_directory('/dir' => %w[dir1])
        real_directory('/dir/dir1' => %w[foo])

        symlink('/dir/dir1/foo' => '/dir/dir2')
        dir_entries_for('/dir/dir1/foo' => %w[bar])
        lstat(realpath(file('/dir/dir1/foo/bar')))

        real_directory('/dir/dir2' => %w[bar])
        lstat(file('/dir/dir2/bar'))
      end

      it 'shows message' do
        expect(STDERR).to_not receive(:puts)
        record.build
      end
    end

    context 'with subdir containing symlinked file' do
      subject { record.paths }
      before do
        real_directory('/dir' => %w[dir1 dir2])
        real_directory('/dir/dir1' => %w[foo])
        lstat(file('/dir/dir1/foo'))
        real_directory('/dir/dir2' => [])
      end

      it 'shows a warning' do
        expect(STDERR).to_not receive(:puts)

        record.build
      end
    end
  end
end
