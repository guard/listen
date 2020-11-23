# frozen_string_literal: true

include Listen

RSpec.describe Directory do
  def fake_file_stat(name, options = {})
    defaults = { directory?: false }
    instance_double(::File::Stat, name, defaults.merge(options))
  end

  def fake_dir_stat(name, options = {})
    defaults = { directory?: true }
    instance_double(::File::Stat, name, defaults.merge(options))
  end

  def fake_children(exception, dir, *args, &block)
    if block_given?
      exception.send(:allow, dir).to receive(:children, &block)
    else
      exception.send(:allow, dir).to receive(:children).and_return(*args)
    end
    exception.send(:allow, dir).to receive(:exist?).and_return(true)
    exception.send(:allow, dir).to receive(:directory?).and_return(true)
  end

  let(:dir) { double(:dir) }
  let(:file) { fake_path('file.rb') }
  let(:file2) { fake_path('file2.rb') }
  let(:subdir) { fake_path('subdir') }

  let(:record) do
    instance_double(
      Record,
      root: 'some_dir',
      dir_entries: record_entries,
      add_dir: true,
      unset_path: true)
  end

  let(:snapshot) { instance_double(Change, record: record, invalidate: nil) }

  before do
    allow(dir).to receive(:+).with('.') { dir }
    allow(dir).to receive(:+).with('file.rb') { file }
    allow(dir).to receive(:+).with('subdir') { subdir }

    allow(file).to receive(:relative_path_from).with(dir) { 'file.rb' }
    allow(file2).to receive(:relative_path_from).with(dir) { 'file2.rb' }
    allow(subdir).to receive(:relative_path_from).with(dir) { 'subdir' }

    allow(Pathname).to receive(:new).with('some_dir').and_return(dir)
    allow(Pathname).to receive(:new).with('.').and_return(dir)

    allow(::File).to receive(:lstat) do |*args|
      fail "Not stubbed: File.lstat(#{args.map(&:inspect) * ','})"
    end
  end

  context '#scan with recursive off' do
    let(:options) { { recursive: false } }

    context 'with file & subdir in record' do
      let(:record_entries) do
        { 'file.rb' => { mtime: 1.1 }, 'subdir' => {} }.freeze
      end

      context 'with empty dir' do
        before { fake_children(self, dir, []) }

        it 'sets record dir path' do
          expect(record).to receive(:add_dir).with('.')
          described_class.scan(snapshot, '.', options)
        end

        it "snapshots changes for file path and dir that doesn't exist" do
          expect(snapshot).to receive(:invalidate).with(:file, 'file.rb', {})

          expect(snapshot).to receive(:invalidate).
            with(:dir, 'subdir', recursive: false)

          described_class.scan(snapshot, '.', options)
        end
      end

      context 'when subdir is removed' do
        before do
          fake_children(self, dir, [file])
          allow(::File).to receive(:lstat).with('file.rb').
            and_return(fake_file_stat('file.rb'))
        end

        it 'notices subdir does not exist' do
          expect(snapshot).to receive(:invalidate).
            with(:dir, 'subdir', recursive: false)

          described_class.scan(snapshot, '.', options)
        end
      end

      context 'when file.rb removed' do
        before do
          fake_children(self, dir, [subdir])

          allow(::File).to receive(:lstat).with('subdir').
            and_return(fake_dir_stat('subdir'))
        end

        it 'notices file was removed' do
          expect(snapshot).to receive(:invalidate).with(:file, 'file.rb', {})
          described_class.scan(snapshot, '.', options)
        end
      end

      context 'when file.rb no longer exists after scan' do
        before do
          fake_children(self, dir, [file], [file2])

          allow(::File).to receive(:lstat).with('file.rb').
            and_raise(Errno::ENOENT)

          allow(::File).to receive(:lstat).with('file2.rb').
            and_return(fake_file_stat('file2.rb'))
        end

        it 'rescans' do
          expect(snapshot).to receive(:invalidate).with(:file, 'file2.rb', {})
          described_class.scan(snapshot, '.', options)
        end
      end

      context 'when file2.rb is added' do
        before do
          fake_children(self, dir, [file, file2, subdir])

          allow(::File).to receive(:lstat).with('file.rb').
            and_return(fake_file_stat('file.rb'))

          allow(::File).to receive(:lstat).with('file2.rb').
            and_return(fake_file_stat('file2.rb'))

          allow(::File).to receive(:lstat).with('subdir').
            and_return(fake_dir_stat('subdir'))
        end

        it 'notices file removed and file2 changed' do
          expect(snapshot).to receive(:invalidate).with(:file, 'file2.rb', {})
          described_class.scan(snapshot, '.', options)
        end
      end
    end

    context 'with empty record' do
      let(:record_entries) { {} }

      context 'with non-existing dir path' do
        before { fake_children(self, dir) { fail Errno::ENOENT } }

        it 'reports no changes' do
          expect(snapshot).to_not receive(:invalidate)
          described_class.scan(snapshot, '.', options)
        end

        it 'unsets record dir path' do
          expect(record).to receive(:unset_path).with('.')
          described_class.scan(snapshot, '.', options)
        end
      end

      context 'when network share is disconnected' do
        before { fake_children(self, dir) { fail Errno::EHOSTDOWN } }

        it 'reports no changes' do
          expect(snapshot).to_not receive(:invalidate)
          described_class.scan(snapshot, '.', options)
        end

        it 'unsets record dir path' do
          expect(record).to receive(:unset_path).with('.')
          described_class.scan(snapshot, '.', options)
        end
      end

      context 'with file.rb in dir' do
        before do
          fake_children(self, dir, [file])

          allow(::File).to receive(:lstat).with('file.rb').
            and_return(fake_file_stat('file.rb'))
        end

        it 'snapshots changes for file & file2 paths' do
          expect(snapshot).to receive(:invalidate).
            with(:file, 'file.rb', {})

          expect(snapshot).to_not receive(:invalidate).
            with(:file, 'file2.rb', {})

          expect(snapshot).to_not receive(:invalidate).
            with(:dir, 'subdir', recursive: false)

          described_class.scan(snapshot, '.', options)
        end
      end
    end
  end

  context '#scan with recursive on' do
    let(:options) { { recursive: true } }

    context 'with file.rb & subdir in record' do
      let(:record_entries) do
        { 'file.rb' => { mtime: 1.1 }, 'subdir' => {} }
      end

      context 'with empty dir' do
        before { fake_children(self, dir, []) }

        it 'snapshots changes for file & subdir path' do
          expect(snapshot).to receive(:invalidate).with(:file, 'file.rb', {})

          expect(snapshot).to receive(:invalidate).
            with(:dir, 'subdir', recursive: true)

          described_class.scan(snapshot, '.', options)
        end
      end

      context 'with subdir2 path present' do
        let(:subdir2) { fake_path('subdir2', children: []) }

        before do
          fake_children(self, dir, [subdir2])
          allow(subdir2).to receive(:relative_path_from).with(dir) { 'subdir2' }

          allow(::File).to receive(:lstat).with('subdir2').
            and_return(fake_dir_stat('subdir2'))
        end

        it 'snapshots changes for file, file2 & subdir paths' do
          expect(snapshot).to receive(:invalidate).with(:file, 'file.rb', {})

          expect(snapshot).to receive(:invalidate).
            with(:dir, 'subdir', recursive: true)

          expect(snapshot).to receive(:invalidate).
            with(:dir, 'subdir2', recursive: true)

          described_class.scan(snapshot, '.', options)
        end
      end
    end

    context 'with empty record' do
      let(:record_entries) { {} }

      context 'with non-existing dir' do
        before do
          fake_children(self, dir) { fail Errno::ENOENT }
        end

        it 'reports no changes' do
          expect(snapshot).to_not receive(:invalidate)
          described_class.scan(snapshot, '.', options)
        end
      end

      context 'with subdir present in dir' do
        before do
          fake_children(self, dir, [subdir])
          fake_children(self, subdir, [])
          allow(::File).to receive(:lstat).with('subdir').
            and_return(fake_dir_stat('subdir'))
        end

        it 'snapshots changes for subdir' do
          expect(snapshot).to receive(:invalidate).
            with(:dir, 'subdir', recursive: true)

          described_class.scan(snapshot, '.', options)
        end
      end
    end
  end
end
