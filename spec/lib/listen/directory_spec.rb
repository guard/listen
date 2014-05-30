require 'spec_helper'

include Listen

describe Directory do
  let(:path) { Pathname.pwd }
  let(:dir) { path + 'dir' }
  let(:file) { dir + 'file.rb' }
  let(:file2) { dir + 'file2.rb' }
  let(:subdir) { dir + 'subdir' }
  let(:subdir2) { instance_double(Pathname, directory?: true) }

  let(:queue) { instance_double(Change, change: nil) }

  let(:async_record) do
    instance_double(Record, set_path: true, unset_path: true)
  end

  let(:record) do
    instance_double(Record, async: async_record, dir_entries: record_entries)
  end

  context '#scan with recursive off' do
    let(:options) { { recursive: false } }

    context 'with file & subdir in record' do
      let(:record_entries) do
        { 'file.rb' => { type: :file }, 'subdir' => { type: :dir } }
      end

      context 'with empty dir' do
        before { allow(dir).to receive(:children) { [] } }

        it 'sets record dir path' do
          expect(async_record).to receive(:set_path).with(:dir, dir)
          described_class.scan(queue, record, dir, options)
        end

        it "queues changes for file path and dir that doesn't exist" do
          expect(queue).to receive(:change).with(:file, file)

          expect(queue).to receive(:change).
            with(:dir, subdir, recursive: false)

          described_class.scan(queue, record, dir, options)
        end
      end

      context 'with file2.rb in dir' do
        before { allow(dir).to receive(:children) { [file2] } }

        it 'notices file & file2 and no longer existing dir' do
          expect(queue).to receive(:change).with(:file, file)
          expect(queue).to receive(:change).with(:file, file2)

          expect(queue).to receive(:change).
            with(:dir, subdir, recursive: false)

          described_class.scan(queue, record, dir, options)
        end
      end
    end

    context 'with empty record' do
      let(:record_entries) { {} }

      context 'with non-existing dir path' do
        before { allow(dir).to receive(:children) { fail Errno::ENOENT } }

        it 'reports no changes' do
          expect(queue).to_not receive(:change)
          described_class.scan(queue, record, dir, options)
        end

        it 'unsets record dir path' do
          expect(async_record).to receive(:unset_path).with(dir)
          described_class.scan(queue, record, dir, options)
        end
      end

      context 'with file.rb in dir' do
        before { allow(dir).to receive(:children) { [file] } }

        it 'queues changes for file & file2 paths' do
          expect(queue).to receive(:change).with(:file, file)
          expect(queue).to_not receive(:change).with(:file, file2)

          expect(queue).to_not receive(:change).
            with(:dir, subdir, recursive: false)

          described_class.scan(queue, record, dir, options)
        end
      end
    end
  end

  context '#scan with recursive on' do
    let(:options) { { recursive: true } }

    context 'with file.rb & subdir in record' do
      let(:record_entries) do
        { 'file.rb' => { type: :file }, 'subdir' => { type: :dir } }
      end

      context 'with empty dir' do
        before { allow(dir).to receive(:children) { [] } }

        it 'queues changes for file & subdir path' do
          expect(queue).to receive(:change).with(:file, file)

          expect(queue).to receive(:change).
            with(:dir, subdir, recursive: true)

          described_class.scan(queue, record, dir, options)
        end
      end

      context 'with subdir2 path present in dir' do
        before do
          allow(path).to receive(:children) { [dir] }
          allow(dir).to receive(:children) { [subdir2] }
        end

        it 'queues changes for file, file2 & subdir paths' do
          expect(queue).to receive(:change).with(:file, file)

          expect(queue).to receive(:change).
            with(:dir, subdir, recursive: true)

          expect(queue).to receive(:change).
            with(:dir, subdir2, recursive: true)

          described_class.scan(queue, record, dir, options)
        end
      end
    end

    context 'with empty record' do
      let(:record_entries) { {} }

      context 'with non-existing dir' do
        before { allow(dir).to receive(:children) { fail Errno::ENOENT } }

        it 'reports no changes' do
          expect(queue).to_not receive(:change)
          described_class.scan(queue, record, dir, options)
        end
      end

      context 'with subdir2 present in dir' do
        before { allow(dir).to receive(:children) { [subdir2] } }

        it 'queues changes for file & file2 paths' do
          expect(queue).to receive(:change).
            with(:dir, subdir2, recursive: true)

          described_class.scan(queue, record, dir, options)
        end
      end
    end
  end
end
