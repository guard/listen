require 'spec_helper'

describe Listen::File do
  let(:record) { double(Listen::Record, async: double(set_path: true, unset_path: true)) }
  let(:path) { Pathname.new(Dir.pwd) }
  around { |example| fixtures { |path| example.run } }
  before { Celluloid::Actor.stub(:[]).with(:listen_record) { record } }

  describe "#change" do
    let(:file_path) { path.join('file.rb') }
    let(:file) { Listen::File.new(file_path) }
    let(:expected_data) {
      if darwin?
        { type: 'File', mtime: kind_of(Float), mode: kind_of(Integer), md5: kind_of(String) }
      else
        { type: 'File', mtime: kind_of(Float), mode: kind_of(Integer) }
      end
    }

    context "path present in record" do
      let(:record_mtime) { nil }
      let(:record_md5) { nil }
      let(:record_mode) { nil }
      let(:record_data) { { type: 'File', mtime: record_mtime, md5: record_md5, mode: record_mode } }
      before { record.stub_chain(:future, :file_data) { double(value: record_data) } }

      context "non-existing path" do
        it "returns added" do
          file.change.should eq :removed
        end
        it "sets path in record" do
          record.async.should_receive(:unset_path).with(file_path)
          file.change
        end
      end

      context "existing path" do
        around { |example| touch file_path; example.run }

        context "old record path mtime" do
          let(:record_mtime) { (Time.now - 1).to_f }

          it "returns modified" do
            file.change.should eq :modified
          end

          it "sets path in record with expected data" do
            record.async.should_receive(:set_path).with(file_path, expected_data)
            file.change
          end
        end

        context "same record path mtime" do
          let(:record_mtime) { ::File.lstat(file_path).mtime.to_f }
          let(:record_mode)  { ::File.lstat(file_path).mode }
          let(:record_md5)   { Digest::MD5.file(file_path).digest }

          context "same record path mode" do
            it "returns nil" do
              file.change.should be_nil
            end
          end

          context "diferent record path mode" do
            let(:record_mode) { 'foo' }

            it "returns modified" do
              file.change.should eq :modified
            end
          end

          context "same record path md5" do
            it "returns nil" do
              file.change.should be_nil
            end
          end

          context "different record path md5" do
            let(:record_md5) { 'foo' }

            it "returns modified" do
              file.change.should eq :modified
            end
            it "sets path in record with expected data" do
              record.async.should_receive(:set_path).with(file_path, expected_data)
              file.change
            end
          end

        end
      end
    end

    context "path not present in record" do
      before { record.stub_chain(:future, :file_data) { double(value: {}) } }

      context "existing path" do
        around { |example| touch file_path; example.run }

        it "returns added" do
          file.change.should eq :added
        end

        it "sets path in record with expected data" do
          record.async.should_receive(:set_path).with(file_path, expected_data)
          file.change
        end
      end
    end
  end

end
