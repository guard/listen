require 'spec_helper'

describe Listen::Listener do
  let(:adapter)        { mock(Listen::Adapter, :start => true).as_null_object }
  let(:base_directory) { Dir.tmpdir }

  subject { described_class.new(base_directory) }

  before do
    Listen::Adapter.stub(:select_and_initialize) { adapter }
    # Don't build a record of the files inside the base directory.
    subject.directory_record.stub(:build)
  end

  describe '#initialize' do
    context 'with no options' do
      it 'sets the directory' do
        subject.directory.should eq base_directory
      end
    end

    context 'with custom options' do
      subject { described_class.new(base_directory, :ignore => '.ssh', :filter => [/.*\.rb/,/.*\.md/], :latency => 0.5, :force_polling => true) }

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
    it 'builds the directory record' do
      subject.directory_record.should_receive(:build)
      subject.start
    end

    it 'selects and initializes an adapter' do
      Listen::Adapter.should_receive(:select_and_initialize).with(base_directory, {}) { adapter }
      subject.start
    end

    it 'starts the adapter' do
      subject.stub(:initialize_adapter) { adapter }
      adapter.should_receive(:start)
      subject.start
    end
  end

  context 'with a started listener' do
    before do
      subject.stub(:initialize_adapter) { adapter }
      subject.start
    end

    describe '#stop' do
      it "stops adapter" do
        adapter.should_receive(:stop)
        subject.stop
      end
    end

    describe '#pause' do
      it 'sets adapter.paused to true' do
        adapter.should_receive(:paused=).with(true)
        subject.pause
      end

      it 'returns the same listener to allow chaining' do
        subject.pause.should equal subject
      end
    end

    describe '#unpause' do
      it 'sets adapter.paused to false and rebuilds the directory record' do
        subject.directory_record.should_receive(:build)
        adapter.should_receive(:paused=).with(false)
        subject.unpause
      end

      it 'returns the same listener to allow chaining' do
        subject.unpause.should equal subject
      end
    end

    describe '#paused?' do
      it 'returns false when there is no adapter' do
        subject.instance_variable_set(:@adapter, nil)
        subject.should_not be_paused
      end

      it 'returns true when adapter is paused' do
        adapter.should_receive(:paused) { true }
        subject.should be_paused
      end

      it 'returns false when adapter is not paused' do
        adapter.should_receive(:paused) { false }
        subject.should_not be_paused
      end
    end
  end

  describe '#change' do
    it 'sets the callback block' do
      callback = lambda { |modified, added, removed| }
      subject.change(&callback)
      subject.instance_variable_get(:@block).should eq callback
    end

    it 'returns the same listener to allow chaining' do
      subject.change(&Proc.new{}).should equal subject
    end
  end

  describe '#ignore'do
    it 'delegates the work to the directory record' do
      subject.directory_record.should_receive(:ignore).with 'some_directory'
      subject.ignore 'some_directory'
    end

    it 'returns the same listener to allow chaining' do
      subject.ignore('some_directory').should equal subject
    end
  end

  describe '#filter' do
    it 'delegates the work to the directory record' do
      subject.directory_record.should_receive(:filter).with /\.txt$/
      subject.filter /\.txt$/
    end

    it 'returns the same listener to allow chaining' do
      subject.filter(/\.txt$/).should equal subject
    end
  end

  describe '#latency' do
    it 'sets the latency to @adapter_options' do
      subject.latency(0.7)
      subject.instance_variable_get(:@adapter_options).should eq(:latency => 0.7)
    end

    it 'returns the same listener to allow chaining' do
      subject.latency(0.7).should equal subject
    end
  end

  describe '#force_polling' do
    it 'sets force_polling to @adapter_options' do
      subject.force_polling(false)
      subject.instance_variable_get(:@adapter_options).should eq(:force_polling => false)
    end

    it 'returns the same listener to allow chaining' do
      subject.force_polling(true).should equal subject
    end
  end

  describe '#polling_fallback_message' do
    it 'sets custom polling fallback message to @adapter_options' do
      subject.polling_fallback_message('custom message')
      subject.instance_variable_get(:@adapter_options).should eq(:polling_fallback_message => 'custom message')
    end

    it 'sets polling fallback message to false in @adapter_options' do
      subject.polling_fallback_message(false)
      subject.instance_variable_get(:@adapter_options).should eq(:polling_fallback_message => false)
    end

    it 'returns the same listener to allow chaining' do
      subject.polling_fallback_message('custom message').should equal subject
    end
  end
end
