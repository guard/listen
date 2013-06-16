require 'spec_helper'

describe Listen::Directory do
  let(:record) { mock(Listen::Record) }
  let(:change_pool) { mock(Listen::Change) }
  let(:change_pool_async) { stub('ChangePoolAsync') }
  let(:path) { Pathname.new(Dir.pwd) }
  around { |example| fixtures { |path| example.run } }
  before {
    change_pool.stub(:async) { change_pool_async }
    Celluloid::Actor.stub(:[]).with(:record) { record }
    Celluloid::Actor.stub(:[]).with(:change_pool) { change_pool }
  }

  describe "#scan" do
    let(:dir_path) { path.join('dir') }
    let(:file_path) { dir_path.join('file.rb') }
    let(:other_file_path) { dir_path.join('other_file.rb') }
    let(:inside_dir_path) { dir_path.join('inside_dir') }
    let(:other_inside_dir_path) { dir_path.join('other_inside_dir') }
    let(:dir) { Listen::Directory.new(dir_path, options) }

    context "with recursive off" do
      let(:options) { { recursive: false } }

      context "file & inside_dir paths present in record" do
        let(:record_dir_entries) { {
          'file.rb' => { type: 'File' },
          'inside_dir' => { type: 'Dir' } } }
        before { record.stub_chain(:future, :dir_entries) { stub(value: record_dir_entries) } }

        context "empty dir" do
          it "calls change only for file path" do
            change_pool_async.should_receive(:change).with(file_path, type: 'File', recursive: false)
            change_pool_async.should_not_receive(:change).with(inside_dir_path, type: 'Dir', recursive: false)
            dir.scan
          end
        end

        context "other file path present in dir" do
          around { |example|
            mkdir dir_path;
            touch other_file_path;
            example.run }

          it "calls change for file & other_file paths" do
            change_pool_async.should_receive(:change).with(file_path, type: 'File', recursive: false)
            change_pool_async.should_receive(:change).with(other_file_path, type: 'File', recursive: false)
            change_pool_async.should_not_receive(:change).with(inside_dir_path, type: 'Dir', recursive: false)
            dir.scan
          end
        end
      end

      context "dir paths not present in record" do
        before { record.stub_chain(:future, :dir_entries) { stub(value: {}) } }

        context "non-existing dir path" do
          it "calls change only for file path" do
            change_pool_async.should_not_receive(:change)
            dir.scan
          end
        end

        context "other file path present in dir" do
          around { |example|
            mkdir dir_path;
            touch file_path;
            example.run }

          it "calls change for file & other_file paths" do
            change_pool_async.should_receive(:change).with(file_path, type: 'File', recursive: false)
            change_pool_async.should_not_receive(:change).with(other_file_path, type: 'File', recursive: false)
            change_pool_async.should_not_receive(:change).with(inside_dir_path, type: 'Dir', recursive: false)
            dir.scan
          end
        end
      end
    end

    context "with recursive on" do
      let(:options) { { recursive: true } }

      context "file & inside_dir paths present in record" do
        let(:record_dir_entries) { {
          'file.rb' => { type: 'File' },
          'inside_dir' => { type: 'Dir' } } }
        before { record.stub_chain(:future, :dir_entries) { stub(value: record_dir_entries) } }

        context "empty dir" do
          it "calls change for file & inside_dir path" do
            change_pool_async.should_receive(:change).with(file_path, type: 'File', recursive: true)
            change_pool_async.should_receive(:change).with(inside_dir_path, type: 'Dir', recursive: true)
            dir.scan
          end
        end

        context "other inside_dir path present in dir" do
          around { |example|
            mkdir dir_path;
            mkdir other_inside_dir_path;
            example.run }

          it "calls change for file, other_file & inside_dir paths" do
            change_pool_async.should_receive(:change).with(file_path, type: 'File', recursive: true)
            change_pool_async.should_receive(:change).with(inside_dir_path, type: 'Dir', recursive: true)
            change_pool_async.should_receive(:change).with(other_inside_dir_path, type: 'Dir', recursive: true)
            dir.scan
          end
        end
      end

      context "dir paths not present in record" do
        before { record.stub_chain(:future, :dir_entries) { stub(value: {}) } }

        context "non-existing dir path" do
          it "calls change only for file path" do
            change_pool_async.should_not_receive(:change)
            dir.scan
          end
        end

        context "other file path present in dir" do
          around { |example|
            mkdir dir_path;
            mkdir other_inside_dir_path;
            example.run }

          it "calls change for file & other_file paths" do
            change_pool_async.should_receive(:change).with(other_inside_dir_path, type: 'Dir', recursive: true)
            dir.scan
          end
        end
      end
    end
  end

end
