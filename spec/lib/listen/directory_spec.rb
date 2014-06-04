require 'spec_helper'

include Listen

describe Directory do
  let(:dir) { double(:dir) }
  let(:file) { double(:file, directory?: false) }
  let(:file2) { double(:file2, directory?: false) }
  let(:subdir) { double(:subdir, directory?: true) }

  let(:queue) { instance_double(Change, change: nil) }

  let(:async_record) do
    instance_double(Record, add_dir: true, unset_path: true)
  end

  let(:record) do
    instance_double(Record, async: async_record, dir_entries: record_entries)
  end

  before do
    allow(dir).to receive(:+).with('.') { dir }
    allow(dir).to receive(:+).with('file.rb') { file }
    allow(dir).to receive(:+).with('subdir') { subdir }

    allow(file).to receive(:relative_path_from).with(dir) { 'file.rb' }
    allow(file2).to receive(:relative_path_from).with(dir) { 'file2.rb' }
    allow(subdir).to receive(:relative_path_from).with(dir) { 'subdir' }
  end

  context '#scan with recursive off' do
    let(:options) { { recursive: false } }

    context 'with file & subdir in record' do
      let(:record_entries) do
        { 'file.rb' => { mtime: 1.1 }, 'subdir' => {} }
      end

      context 'with empty dir' do
        before { allow(dir).to receive(:children) { [] } }

        it 'sets record dir path' do
          expect(async_record).to receive(:add_dir).with(dir, '.')
          described_class.scan(queue, record, dir, '.', options)
        end

        it "queues changes for file path and dir that doesn't exist" do
          expect(queue).to receive(:change).with(:file, dir, 'file.rb')

          expect(queue).to receive(:change).
            with(:dir, dir, 'subdir', recursive: false)

          described_class.scan(queue, record, dir, '.', options)
        end
      end

      context 'with only file2.rb in dir' do
        before { allow(dir).to receive(:children) { [file2] } }

        it 'notices file & file2 and no longer existing dir' do
          expect(queue).to receive(:change).with(:file, dir, 'file.rb')
          expect(queue).to receive(:change).with(:file, dir, 'file2.rb')

          expect(queue).to receive(:change).
            with(:dir, dir, 'subdir', recursive: false)

          described_class.scan(queue, record, dir, '.', options)
        end
      end
    end

    context 'with empty record' do
      let(:record_entries) { {} }

      context 'with non-existing dir path' do
        before { allow(dir).to receive(:children) { fail Errno::ENOENT } }

        it 'reports no changes' do
          expect(queue).to_not receive(:change)
          described_class.scan(queue, record, dir, '.', options)
        end

        it 'unsets record dir path' do
          expect(async_record).to receive(:unset_path).with(dir, '.')
          described_class.scan(queue, record, dir, '.', options)
        end
      end

      context 'with file.rb in dir' do
        before { allow(dir).to receive(:children) { [file] } }

        it 'queues changes for file & file2 paths' do
          expect(queue).to receive(:change).with(:file, dir, 'file.rb')
          expect(queue).to_not receive(:change).with(:file, dir, 'file2.rb')

          expect(queue).to_not receive(:change).
            with(:dir, dir, 'subdir', recursive: false)

          described_class.scan(queue, record, dir, '.', options)
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
        before do
          allow(dir).to receive(:children) { [] }
        end

        it 'queues changes for file & subdir path' do
          expect(queue).to receive(:change).with(:file, dir, 'file.rb')

          expect(queue).to receive(:change).
            with(:dir, dir, 'subdir', recursive: true)

          described_class.scan(queue, record, dir, '.', options)
        end
      end

      context 'with subdir2 path present in dir' do
        let(:subdir2) { double(:subdir2, directory?: true, children: []) }

        before do
          allow(dir).to receive(:children) { [subdir2] }
          allow(subdir2).to receive(:relative_path_from).with(dir) { 'subdir2' }
        end

        it 'queues changes for file, file2 & subdir paths' do
          expect(queue).to receive(:change).with(:file, dir, 'file.rb')

          expect(queue).to receive(:change).
            with(:dir, dir, 'subdir', recursive: true)

          expect(queue).to receive(:change).
            with(:dir, dir, 'subdir2', recursive: true)

          described_class.scan(queue, record, dir, '.', options)
        end
      end
    end

    context 'with empty record' do
      let(:record_entries) { {} }

      context 'with non-existing dir' do
        before do
          allow(dir).to receive(:children) { fail Errno::ENOENT }
        end

        it 'reports no changes' do
          expect(queue).to_not receive(:change)
          described_class.scan(queue, record, dir, '.', options)
        end
      end

      context 'with subdir present in dir' do

        before do
          allow(dir).to receive(:children) { [subdir] }
          allow(subdir).to receive(:children) { [] }
        end

        it 'queues changes for subdir' do
          expect(queue).to receive(:change).
            with(:dir, dir, 'subdir', recursive: true)

          described_class.scan(queue, record, dir, '.', options)
        end
      end
    end
  end
end
