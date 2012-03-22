require 'spec_helper'

describe Listen::Listener do
  let(:adapter)           { mock(Listen::Adapter, :start => true).as_null_object }
  let(:watched_directory) { Dir.tmpdir }

  subject { described_class.new(watched_directory) }

  before do
    Listen::Adapter.stub(:select_and_initialize) { adapter }
    # Don't build a record of the files inside the base directory.
    subject.directory_record.stub(:build)
  end

  it_should_behave_like 'a listener to changes on a file-system'

  describe '#initialize' do
    context 'with no options' do
      it 'sets the directory' do
        subject.directory.should eq watched_directory
      end
    end

    context 'with custom options' do
      subject { described_class.new(watched_directory, :ignore => '.ssh', :filter => [/.*\.rb/,/.*\.md/], :latency => 0.5, :force_polling => true) }

      it 'passes the custom ignored paths to the directory record' do
        subject.directory_record.ignored_paths.should =~ %w[.bundle .git .DS_Store log tmp vendor .ssh]
      end

      it 'passes the custom filters to the directory record' do
        subject.directory_record.filters.should =~  [/.*\.rb/,/.*\.md/]
      end

      it 'sets adapter_options' do
        subject.instance_variable_get(:@adapter_options).should eq(:latency => 0.5, :force_polling => true)
      end
    end
  end

  describe '#start' do
    it 'selects and initializes an adapter' do
      Listen::Adapter.should_receive(:select_and_initialize).with(watched_directory, {}) { adapter }
      subject.start
    end

    it 'builds the directory record' do
      subject.directory_record.should_receive(:build)
      subject.start
    end
  end

  context 'with a started listener' do
    before do
      subject.stub(:initialize_adapter) { adapter }
      subject.start
    end

    describe '#unpause' do
      it 'rebuilds the directory record' do
        subject.directory_record.should_receive(:build)
        subject.unpause
      end
    end
  end

  describe '#ignore'do
    it 'delegates the work to the directory record' do
      subject.directory_record.should_receive(:ignore).with 'some_directory'
      subject.ignore 'some_directory'
    end
  end

  describe '#filter' do
    it 'delegates the work to the directory record' do
      subject.directory_record.should_receive(:filter).with /\.txt$/
      subject.filter /\.txt$/
    end
  end
end
