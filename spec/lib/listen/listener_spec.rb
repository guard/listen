# require 'spec_helper'

describe Listen::Listener do
  let(:listener) { Listen::Listener.new }

  describe "initialize" do
    it "sets paused to false" do
      listener.should_not be_paused
    end

    it "sets block" do
      block = -> (modified, added, removed) { }
      listener = Listen::Listener.new('dir', &block)
      listener.block.should_not be_nil
    end
  end

  describe "options" do
    it "sets default options" do
      listener.options.should eq({
        latency: nil,
        force_polling: false,
        polling_fallback_message: nil })
    end

    it "sets new options on initialize" do
      listener = Listen::Listener.new('path', latency: 1.234)
      listener.options.should eq({
        latency: 1.234,
        force_polling: false,
        polling_fallback_message: nil })
    end
  end

  # TODO

  # context 'with one path to listen to' do
  #   context 'without options' do
  #     it 'creates an instance of Listener' do
  #       listener_class.should_receive(:new).with('/path')
  #       described_class.to('/path')
  #     end
  #   end

  #   context 'with options' do
  #     it 'creates an instance of Listener with the passed params' do
  #       listener_class.should_receive(:new).with('/path', foo: 'bar')
  #       described_class.to('/path', foo: 'bar')
  #     end
  #   end

  #   context 'without a block' do
  #     it 'returns the listener' do
  #       described_class.to('/path', foo: 'bar').should eq listener
  #     end
  #   end

  #   context 'with a block' do
  #     it 'starts the listener after creating it' do
  #       listener.stub(async: listener)
  #       listener.should_receive(:start)
  #       described_class.to('/path', foo: 'bar') { |modified, added, removed| }
  #     end
  #   end
  # end

  # context 'with multiple paths to listen to' do
  #   context 'without options' do
  #     it 'creates an instance of Listener' do
  #       listener_class.should_receive(:new).with('path1', 'path2')
  #       described_class.to('path1', 'path2')
  #     end
  #   end

  #   context 'with options' do
  #     it 'creates an instance of Listener with the passed params' do
  #       listener_class.should_receive(:new).with('path1', 'path2', foo: 'bar')
  #       described_class.to('path1', 'path2', foo: 'bar')
  #     end
  #   end

  #   context 'without a block' do
  #     it 'returns a Listener instance created with the passed params' do
  #       described_class.to('path1', 'path2', foo: 'bar').should eq listener
  #     end
  #   end

  #   context 'with a block' do
  #     it 'starts a Listener instance after creating it with the passed params' do
  #       listener.stub(async: listener)
  #       listener.should_receive(:start)
  #       described_class.to('path1', 'path2', foo: 'bar') { |modified, added, removed| }
  #     end
  #   end
  # end

  # let(:adapter)             { mock(Listen::Adapter, start: true).as_null_object }
  # let(:watched_directory)   { File.dirname(__FILE__) }
  # let(:watched_directories) { [File.dirname(__FILE__), File.expand_path('../..', __FILE__)] }

  # before do
  #   Listen::Adapter.stub(:select_and_initialize) { adapter }
  #   # Don't build a record of the files inside the base directory.
  #   Listen::DirectoryRecord.any_instance.stub(:build)
  # end
  # subject { described_class.new(watched_directories) }

  # it_should_behave_like 'a listener to changes on a file-system'

  # describe '#initialize' do
  #   context 'listening to a single directory' do
  #     subject { described_class.new(watched_directory) }

  #     it 'sets the directories' do
  #       subject.directories.should eq [watched_directory]
  #     end

  #     context 'with no options' do
  #       it 'sets the option for using relative paths in the callback to true' do
  #         subject.instance_variable_get(:@use_relative_paths).should eq true
  #       end
  #     end

  #     context 'with relative_paths: false' do
  #       it 'sets the option for using relative paths in the callback to false' do
  #         listener = described_class.new(watched_directories, relative_paths: false)
  #         listener.instance_variable_get(:@use_relative_paths).should eq false
  #       end
  #     end
  #   end

  #   context 'listening to multiple directories' do
  #     subject { described_class.new(watched_directories) }

  #     it 'sets the directories' do
  #       subject.directories.should eq watched_directories
  #     end

  #     context 'with no options' do
  #       it 'sets the option for using relative paths in the callback to false' do
  #         subject.instance_variable_get(:@use_relative_paths).should eq false
  #       end
  #     end

  #     context 'with relative_paths: true' do
  #       it 'sets the option for using relative paths in the callback to false' do
  #         listener = described_class.new(watched_directories, relative_paths: true)
  #         listener.instance_variable_get(:@use_relative_paths).should eq false
  #       end
  #     end
  #   end

  #   it 'converts the passed path into an absolute path - #21' do
  #     described_class.new(File.join(watched_directory, '..')).directories.should eq [File.expand_path('..', watched_directory)]
  #   end

  #   context 'with custom options' do
  #     let(:options) do
  #       {
  #         ignore: /\.ssh/, filter: [/.*\.rb/, /.*\.md/],
  #         latency: 0.5, force_polling: true, relative_paths: true
  #       }
  #     end
  #     subject { described_class.new(watched_directory, options) }

  #     it 'passes the custom ignored paths to the directory record' do
  #       subject.directories_records.each do |directory_record|
  #         directory_record.ignoring_patterns.should include /\.ssh/
  #       end
  #     end

  #     it 'passes the custom filters to the directory record' do
  #       subject.directories_records.each do |directory_record|
  #         directory_record.filtering_patterns.should =~  [/.*\.rb/,/.*\.md/]
  #       end
  #     end

  #     it 'sets adapter_options' do
  #       subject.instance_variable_get(:@adapter_options).should eq(latency: 0.5, force_polling: true)
  #     end
  #   end
  # end

  # describe '#start' do
  #   it 'selects and initializes an adapter' do
  #     Listen::Adapter.should_receive(:select_and_initialize).with(watched_directories, {}) { adapter }
  #     subject.start
  #   end

  #   it 'builds the directory record' do
  #     subject.directories_records.each do |directory_record|
  #       directory_record.should_receive(:build)
  #     end
  #     subject.start
  #   end
  # end

  # context 'with a started listener' do
  #   before do
  #     subject.stub(:initialize_adapter) { adapter }
  #     subject.start
  #   end

  #   describe '#unpause' do
  #     it 'rebuilds the directory record' do
  #       subject.directories_records.each do |directory_record|
  #         directory_record.should_receive(:build)
  #       end
  #       subject.unpause
  #     end
  #   end
  # end

  # describe '#ignore'do
  #   it 'delegates the work to the directory record' do
  #     subject.directories_records.each do |directory_record|
  #       directory_record.should_receive(:ignore).with 'some_directory'
  #     end
  #     subject.ignore 'some_directory'
  #   end
  # end

  # describe '#ignore!'do
  #   it 'delegates the work to the directory record' do
  #     subject.directories_records.each do |directory_record|
  #       directory_record.should_receive(:ignore!).with 'some_directory'
  #     end
  #     subject.ignore! 'some_directory'
  #   end
  # end

  # describe '#filter' do
  #   it 'delegates the work to the directory record' do
  #     subject.directories_records.each do |directory_record|
  #       directory_record.should_receive(:filter).with /\.txt$/
  #     end
  #     subject.filter /\.txt$/
  #   end
  # end

  # describe '#filter!' do
  #   it 'delegates the work to the directory record' do
  #     subject.directories_records.each do |directory_record|
  #       directory_record.should_receive(:filter!).with /\.txt$/
  #     end
  #     subject.filter! /\.txt$/
  #   end
  # end

  # describe '#on_change' do
  #   let(:directories) { %w{dir1 dir2 dir3} }
  #   let(:changes)     { {modified: [], added: [], removed: []} }
  #   let(:callback)    { Proc.new { @called = true } }

  #   before do
  #     @called = false
  #     subject.stub(fetch_records_changes: changes)
  #   end

  #   it 'fetches the changes of all directories records' do
  #     subject.unstub(:fetch_records_changes)

  #     subject.directories_records.each do |record|
  #       record.should_receive(:fetch_changes).with(directories, an_instance_of(Hash)).and_return(changes)
  #     end
  #     subject.on_change(directories)
  #   end

  #   context 'with no changes to report' do
  #     if RUBY_VERSION[/^1.8/]
  #       it 'does not run the callback' do
  #           subject.change(&callback)
  #           subject.on_change(directories)
  #           @called.should be_false
  #       end
  #     else
  #       it 'does not run the callback' do
  #         callback.should_not_receive(:call)
  #         subject.change(&callback)
  #         subject.on_change(directories)
  #       end
  #     end
  #   end

  #   context 'with changes to report' do
  #     let(:changes) do
  #       {
  #         modified: %w{path1}, added: [], removed: %w{path2}
  #       }
  #     end

  #     if RUBY_VERSION[/^1.8/]
  #       it 'runs the callback passing it the changes' do
  #         subject.change(&callback)
  #         subject.on_change(directories)
  #         @called.should be_true
  #       end
  #     else
  #       it 'runs the callback passing it the changes' do
  #         callback.should_receive(:call).with(changes[:modified], changes[:added], changes[:removed])
  #         subject.change(&callback)
  #         subject.on_change(directories)
  #       end
  #     end
  #   end
  # end
end
