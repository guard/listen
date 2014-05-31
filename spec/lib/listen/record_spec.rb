require 'spec_helper'

describe Listen::Record do
  let(:registry) { instance_double(Celluloid::Registry) }

  let(:listener) do
    instance_double(Listen::Listener, registry: registry, options: {})
  end

  let(:record) { Listen::Record.new(listener) }
  let(:path) { '/dir/path/file.rb' }

  describe '#set_path' do
    it 'sets path by spliting dirname and basename' do
      record.set_path(:file, path)
      expect(record.paths['/dir/path']).to eq('file.rb' => { type: :file })
    end

    it 'sets path and keeps old data not overwritten' do
      record.set_path(:file, path, foo: 1, bar: 2)
      record.set_path(:file, path, foo: 3)
      file_data = record.paths['/dir/path']['file.rb']
      expect(file_data).to eq(foo: 3, bar: 2, type: :file)
    end
  end

  describe '#unset_path' do
    context 'path is present' do
      before { record.set_path(:file, path) }

      it 'unsets path' do
        record.unset_path(path)
        expect(record.paths).to eq('/dir/path' => {})
      end
    end

    context 'path not present' do
      it 'unsets path' do
        record.unset_path(path)
        expect(record.paths).to eq('/dir/path' => {})
      end
    end
  end

  describe '#file_data' do
    context 'path is present' do
      before { record.set_path(:file, path) }

      it 'returns file data' do
        expect(record.file_data(path)).to eq(type: :file)
      end
    end

    context 'path not present' do
      it 'return empty hash' do
        expect(record.file_data(path)).to be_empty
      end
    end
  end

  describe '#dir_entries' do
    context 'path is present' do
      before { record.set_path(:file, path) }

      it 'returns file path' do
        entries = record.dir_entries('/dir/path')
        expect(entries).to eq('file.rb' => { type: :file })
      end
    end

    context 'path not present' do
      it 'unsets path' do
        expect(record.dir_entries('/dir/path')).to eq({})
      end
    end
  end

  describe '#build' do
    let(:directories) { ['dir_path'] }

    let(:actor) do
      instance_double(Listen::Change, change: nil, terminate: true)
    end

    before do
      allow(listener).to receive(:directories) { directories }
      allow(listener).to receive(:sync).with(:change_pool) { actor }
    end

    it 're-inits paths' do
      record.set_path(:file, path)
      record.build
      expect(record.file_data(path)).to be_empty
    end

    it 'calls change asynchronously on all directories to build record'  do
      expect(actor).to receive(:change).
        with(:dir, 'dir_path', recursive: true, silence: true, build: true)
      record.build
    end
  end

  describe '#still_building!' do
    let(:directories) { ['dir_path'] }

    let(:actor) do
      instance_double(Listen::Change, change: nil, terminate: true)
    end

    before do
      allow(listener).to receive(:directories) { directories }
      allow(listener).to receive(:sync).with(:change_pool) { actor }
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
