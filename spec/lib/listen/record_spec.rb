require 'spec_helper'

describe Listen::Record do
  let(:record) { Listen::Record.new }
  let(:path) { '/dir/path/file.rb' }
  let(:data) { { type: 'File' } }

  describe "#set_path" do
    it "sets path by spliting direname and basename" do
      record.set_path(path, data)
      record.paths.should eq({ '/dir/path' => { 'file.rb' => data } })
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
      it "return nil" do
        record.file_data(path).should be_nil
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
end
