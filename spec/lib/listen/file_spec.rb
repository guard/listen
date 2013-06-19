require 'spec_helper'

describe Listen::File do
  let(:record) { mock(Listen::Record, async: stub(set_path: true, unset_path: true)) }
  let(:path) { Pathname.new(Dir.pwd) }
  around { |example| fixtures { |path| example.run } }
  before { Celluloid::Actor.stub(:[]).with(:listen_record) { record } }

  describe "#change" do
    let(:file_path) { path.join('file.rb') }
    let(:file) { Listen::File.new(file_path) }

    context "path present in record" do
      let(:record_mtime) { nil }
      let(:record_md5) { nil }
      let(:record_mode) { nil }
      let(:record_data) { { type: 'File', mtime: record_mtime, md5: record_md5, mode: record_mode } }
      before { record.stub_chain(:future, :file_data) { stub(value: record_data) } }

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
          it "sets path in record with mtime" do
            record.async.should_receive(:set_path).with(file_path, {type: 'File', mtime: kind_of(Float) })
            file.change
          end
        end

        context "same record path mtime" do
          let(:record_mtime) { ::File.lstat(file_path).mtime.to_f }

          context "different record path md5" do
            let(:record_md5) { 'foo' }

            it "returns modified" do
              file.change.should eq :modified
            end
            it "sets path in record with mtime and md5" do
              record.async.should_receive(:set_path).with(file_path, {type: 'File', mtime: kind_of(Float), md5: kind_of(String) })
              file.change
            end
          end

          context "none record path md5" do
            let(:record_md5) { nil }

            it "doesn't returns modified" do
              file.change.should be_nil
            end
            it "sets path in record with mtime, md5 and mode" do
              record.async.should_receive(:set_path).with(file_path, {type: 'File', mtime: kind_of(Float), md5: kind_of(String), mode: kind_of(Integer)})
              file.change
            end
          end

          context "same record path md5" do
            let(:record_md5) { Digest::MD5.file(file_path).digest }

            it "returns modified" do
              file.change.should be_nil
            end
          end

          context "none record path mode" do
            let(:record_mode) { nil }

            it "doesn't returns modified" do
              file.change.should be_nil
            end
            it "sets path in record with mtime, md5 and mode" do
              record.async.should_receive(:set_path).with(file_path, {type: 'File', mtime: kind_of(Float), md5: kind_of(String), mode: kind_of(Integer)})
              file.change
            end
          end

          context "same record path mode" do
            let(:record_mode) { ::File.lstat(file_path).mode }

            it "returns modified" do
              file.change.should be_nil
            end
          end
        end
      end
    end

    context "path not present in record" do
      before { record.stub_chain(:future, :file_data) { stub(value: {}) } }

      context "existing path" do
        around { |example| touch file_path; example.run }

        it "returns added" do
          file.change.should eq :added
        end
        it "sets path in record with mtime" do
          record.async.should_receive(:set_path).with(file_path, {type: 'File', mtime: kind_of(Float) })
          file.change
        end
      end
    end
  end

end
