require 'spec_helper'

describe Listen::Directory do
  let(:registry) { double(Celluloid::Registry) }
  let(:listener) { double(Listen::Listener, registry: registry, options: {}) }

  let(:record) do
    double(Listen::Record, async: double(set_path: true, unset_path: true))
  end

  let(:change_pool_async) { double(Listen::Change) }
  let(:actor) { double('ChangeProxy', async: change_pool_async) }
  let(:path) { Pathname.new(Dir.pwd) }
  around { |example| fixtures { example.run } }
  before do
    allow(registry).to receive(:[]).with(:record) { record }
    allow(registry).to receive(:[]).with(:change_pool) { actor }
  end

  describe '#scan' do
    let(:dir_path) { path.join('dir') }
    let(:file_path) { dir_path.join('file.rb') }
    let(:other_file_path) { dir_path.join('other_file.rb') }
    let(:inside_dir_path) { dir_path.join('inside_dir') }
    let(:other_inside_dir_path) { dir_path.join('other_inside_dir') }
    let(:dir) { Listen::Directory.new(listener, dir_path, options) }

    context 'with recursive off' do
      let(:options) { { recursive: false } }

      context 'file & inside_dir paths present in record' do
        let(:record_dir_entries) do
          {
            'file.rb' => { type: 'File' },
            'inside_dir' => { type: 'Dir' }
          }
        end

        before do
          allow(record).to receive_message_chain(:future, :dir_entries) do
            double(value: record_dir_entries)
          end

          allow(change_pool_async).to receive(:change)
        end

        context 'empty dir' do
          around do |example|
            mkdir dir_path
            example.run
          end

          it 'sets record dir path' do
            expect(record.async).to receive(:set_path).
              with(dir_path, type: 'Dir')
            dir.scan
          end

          it "calls change for file path and dir that doesn't exist" do
            expect(change_pool_async).to receive(:change).
              with(file_path, type: 'File', recursive: false)

            expect(change_pool_async).to receive(:change).
              with(inside_dir_path, type: 'Dir', recursive: false)

            dir.scan
          end
        end

        context 'other file path present in dir' do
          around do |example|
            mkdir dir_path
            touch other_file_path
            example.run
          end

          it 'notices file & other_file and no longer existing dir' do
            expect(change_pool_async).to receive(:change).
              with(file_path, type: 'File', recursive: false)

            expect(change_pool_async).to receive(:change).
              with(other_file_path, type: 'File', recursive: false)

            expect(change_pool_async).to receive(:change).
              with(inside_dir_path, type: 'Dir', recursive: false)

            dir.scan
          end
        end
      end

      context 'dir paths not present in record' do
        before do
          allow(record).to receive_message_chain(:future, :dir_entries) { double(value: {}) }
        end

        context 'non-existing dir path' do
          it 'calls change only for file path' do
            expect(change_pool_async).to_not receive(:change)
            dir.scan
          end

          it 'unsets record dir path' do
            expect(record.async).to receive(:unset_path).with(dir_path)
            dir.scan
          end
        end

        context 'other file path present in dir' do
          around do |example|
            mkdir dir_path
            touch file_path
            example.run
          end

          it 'calls change for file & other_file paths' do
            expect(change_pool_async).to receive(:change).
              with(file_path, type: 'File', recursive: false)

            expect(change_pool_async).to_not receive(:change).
              with(other_file_path, type: 'File', recursive: false)

            expect(change_pool_async).to_not receive(:change).
              with(inside_dir_path, type: 'Dir', recursive: false)

            dir.scan
          end
        end
      end
    end

    context 'with recursive on' do
      let(:options) { { recursive: true } }

      context 'file & inside_dir paths present in record' do
        let(:record_dir_entries) do {
          'file.rb' => { type: 'File' },
          'inside_dir' => { type: 'Dir' } }
        end

        before do
          allow(record).to receive_message_chain(:future, :dir_entries) do
            double(value: record_dir_entries)
          end
        end

        context 'empty dir' do
          it 'calls change for file & inside_dir path' do
            expect(change_pool_async).to receive(:change).
              with(file_path, type: 'File', recursive: true)

            expect(change_pool_async).to receive(:change).
              with(inside_dir_path, type: 'Dir', recursive: true)

            dir.scan
          end
        end

        context 'other inside_dir path present in dir' do
          around do |example|
            mkdir dir_path
            mkdir other_inside_dir_path
            example.run
          end

          it 'calls change for file, other_file & inside_dir paths' do
            expect(change_pool_async).to receive(:change).
              with(file_path, type: 'File', recursive: true)

            expect(change_pool_async).to receive(:change).
              with(inside_dir_path, type: 'Dir', recursive: true)

            expect(change_pool_async).to receive(:change).
              with(other_inside_dir_path, type: 'Dir', recursive: true)

            dir.scan
          end
        end
      end

      context 'dir paths not present in record' do
        before do
          allow(record).to receive_message_chain(:future, :dir_entries) { double(value: {}) }
        end

        context 'non-existing dir path' do
          it 'calls change only for file path' do
            expect(change_pool_async).to_not receive(:change)
            dir.scan
          end
        end

        context 'other file path present in dir' do
          around do |example|
            mkdir dir_path
            mkdir other_inside_dir_path
            example.run
          end

          it 'calls change for file & other_file paths' do
            expect(change_pool_async).to receive(:change).
              with(other_inside_dir_path, type: 'Dir', recursive: true)

            dir.scan
          end
        end
      end
    end
  end

end
