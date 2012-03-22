require 'spec_helper'

describe Listen::MultiListener do
  let(:adapter)             { mock(Listen::Adapter, :start => true).as_null_object }
  let(:watched_directories) { [File.dirname(__FILE__), Dir.tmpdir] }

  subject { described_class.new(*watched_directories) }

  before do
    Listen::Adapter.stub(:select_and_initialize) { adapter }
    # Don't build a record of the files inside the base directory.
    Listen::DirectoryRecord.any_instance.stub(:build)
  end

  it_should_behave_like 'a listener to changes on a file-system'

  describe '#initialize' do
    context 'with no options' do
      it 'sets the directories' do
        subject.directories.should =~ watched_directories
      end
    end

    context 'with custom options' do
      subject do
        args = watched_directories << {:ignore => '.ssh', :filter => [/.*\.rb/,/.*\.md/], :latency => 0.5, :force_polling => true}
        described_class.new(*args)
      end

      it 'passes the custom ignored paths to each directory record' do
        subject.directories_records.each do |r|
          r.ignored_paths.should =~ %w[.bundle .git .DS_Store log tmp vendor .ssh]
        end
      end

      it 'passes the custom filters to each directory record' do
        subject.directories_records.each do |r|
          r.filters.should =~  [/.*\.rb/,/.*\.md/]
        end
      end

      it 'sets adapter_options' do
        subject.instance_variable_get(:@adapter_options).should eq(:latency => 0.5, :force_polling => true)
      end
    end
  end

  describe '#start' do
    it 'selects and initializes an adapter' do
      Listen::Adapter.should_receive(:select_and_initialize).with(watched_directories, {}) { adapter }
      subject.start
    end

    it 'builds all directories records' do
      subject.directories_records.each do |r|
        r.should_receive(:build)
      end
      subject.start
    end
  end

  context 'with a started listener' do
    before do
      subject.stub(:initialize_adapter) { adapter }
      subject.start
    end

    describe '#unpause' do
      it 'rebuilds all directories records' do
        subject.directories_records.each do |r|
          r.should_receive(:build)
        end
        subject.unpause
      end
    end
  end

  describe '#ignore'do
    it 'delegates the work to each directory record' do
      subject.directories_records.each do |r|
        r.should_receive(:ignore).with 'some_directory'
      end
      subject.ignore 'some_directory'
    end
  end

  describe '#filter' do
    it 'delegates the work to each directory record' do
      subject.directories_records.each do |r|
        r.should_receive(:filter).with /\.txt$/
      end
      subject.filter /\.txt$/
    end
  end
end
