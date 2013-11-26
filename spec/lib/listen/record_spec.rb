require 'spec_helper'

describe Listen::Record do
  let(:registry) { double(Celluloid::Registry) }
  let(:listener) { double(Listen::Listener, registry: registry, options: {}) }
  let(:record) { Listen::Record.new(listener) }
  let(:path) { '/dir/path/file.rb' }
  let(:data) { { type: 'File' } }

  describe "#set_path" do
    it "sets path by spliting direname and basename" do
      record.set_path(path, data)
      expect(record.paths).to eq({ '/dir/path' => { 'file.rb' => data } })
    end

    it "sets path and keeps old data not overwritten" do
      record.set_path(path, data.merge(foo: 1, bar: 2))
      record.set_path(path, data.merge(foo: 3))
      expect(record.paths).to eq({ '/dir/path' => { 'file.rb' => data.merge(foo: 3, bar: 2) } })
    end
  end

  describe "#unset_path" do
    context "path is present" do
      before { record.set_path(path, data) }

      it "unsets path" do
        record.unset_path(path)
        expect(record.paths).to eq({ '/dir/path' => {} })
      end
    end

    context "path not present" do
      it "unsets path" do
        record.unset_path(path)
        expect(record.paths).to eq({ '/dir/path' => {} })
      end
    end
  end

  describe "#file_data" do
    context "path is present" do
      before { record.set_path(path, data) }

      it "returns file data" do
        expect(record.file_data(path)).to eq data
      end
    end

    context "path not present" do
      it "return empty hash" do
        expect(record.file_data(path)).to be_empty
      end
    end
  end

  describe "#dir_entries" do
    context "path is present" do
      before { record.set_path(path, data) }

      it "returns file path" do
        expect(record.dir_entries('/dir/path')).to eq({ 'file.rb' => data })
      end
    end

    context "path not present" do
      it "unsets path" do
        expect(record.dir_entries('/dir/path')).to eq({})
      end
    end
  end

  describe "#build" do
    let(:directories) { ['dir_path'] }
    let(:change_pool) { double(Listen::Change, terminate: true) }
    before {
      change_pool.stub(:change)
      registry.stub(:[]).with(:change_pool) { change_pool }
      listener.stub(:directories) { directories }
    }

    it "re-inits paths" do
      record.set_path(path, data)
      record.build
      expect(record.file_data(path)).to be_empty
    end

    it "calls change asynchronously on all directories to build record"  do
      expect(change_pool).to receive(:change).with('dir_path', type: 'Dir', recursive: true, silence: true)
      record.build
    end
  end
end
