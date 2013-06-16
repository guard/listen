require 'spec_helper'

describe Listen::Record do
  let(:listener) { mock(Listen::Listener, options: {}) }
  let(:record) { Listen::Record.new(listener) }
  let(:path) { '/dir/path/file.rb' }
  let(:data) { { type: 'File' } }

  describe "#set_path" do
    it "sets path by spliting direname and basename" do
      record.set_path(path, data)
      record.paths.should eq({ '/dir/path' => { 'file.rb' => data } })
    end

    it "sets path and keeps old data not overwritten" do
      record.set_path(path, data.merge(foo: 1, bar: 2))
      record.set_path(path, data.merge(foo: 3))
      record.paths.should eq({ '/dir/path' => { 'file.rb' => data.merge(foo: 3, bar: 2) } })
    end
  end

  describe "#unset_path" do
    context "path is present" do
      before { record.set_path(path, data) }

      it "unsets path" do
        record.unset_path(path)
        record.paths.should eq({ '/dir/path' => {} })
      end
    end

    context "path not present" do
      it "unsets path" do
        record.unset_path(path)
        record.paths.should eq({ '/dir/path' => {} })
      end
    end
  end

  describe "#file_data" do
    context "path is present" do
      before { record.set_path(path, data) }

      it "returns file data" do
        record.file_data(path).should eq data
      end
    end

    context "path not present" do
      it "return empty hash" do
        record.file_data(path).should be_empty
      end
    end
  end

  describe "#dir_entries" do
    context "path is present" do
      before { record.set_path(path, data) }

      it "returns file path" do
        record.dir_entries('/dir/path').should eq({ 'file.rb' => data })
      end
    end

    context "path not present" do
      it "unsets path" do
        record.dir_entries('/dir/path').should eq({})
      end
    end
  end

  describe "#build" do
    let(:directories) { ['dir_path'] }
    let(:change_pool) { mock(Listen::Change, terminate: true) }
    let(:change_pool_async) { stub('ChangePoolAsync', change: true) }
    before {
      change_pool.stub(:async) { change_pool_async }
      Celluloid::Actor.stub(:[]).with(:change_pool) { change_pool }
      listener.stub(:directories) { directories }
    }

    it "re-inits paths" do
      record.set_path(path, data)
      record.build
      record.file_data(path).should be_empty
    end

    it "calls change asynchronously on all directories to build record"  do
      change_pool_async.should_receive(:change).with('dir_path', type: 'Dir', recursive: true, silence: true)
      record.build
    end
  end
end
