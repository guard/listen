require 'spec_helper'

describe Listen::Adapter do
  let(:listener) { mock(Listen::Listener) }

  subject { described_class.new(listener) }

  before do
    Listen::Adapters::Darwin.stub(:usable?)  { false }
    Listen::Adapters::Linux.stub(:usable?)   { false }
    Listen::Adapters::Windows.stub(:usable?) { false }
  end

  describe '#initialize' do
    it 'sets the latency to the default one' do
      subject.latency.should eq described_class::DEFAULT_LATENCY
    end
  end

  describe ".select_and_initialize" do
    context "with no specific adapter usable" do
      it "returns Listen::Adapters::Polling instance" do
        Listen::Adapters::Polling.should_receive(:new).with(listener)
        described_class.select_and_initialize(listener)
      end

      context 'when the use of the polling adapter is disabled' do
        it 'raises an error' do
          expect {
            described_class.select_and_initialize(listener, :use_polling => false)
          }.to raise_error(
            RuntimeError, 'No OS-specific adapter could be used on your machine and the use of the polling apdapter is disabled.'
          )
        end
      end
    end

    context "on Mac OX >= 10.6" do
      before { Listen::Adapters::Darwin.stub(:usable?) { true } }

      it "uses Listen::Adapters::Darwin" do
        Listen::Adapters::Darwin.should_receive(:new).with(listener)
        described_class.select_and_initialize(listener)
      end

      context 'when the use of the polling adapter is forced' do
        it 'uses Listen::Adapters::Polling' do
          Listen::Adapters::Polling.should_receive(:new).with(listener)
          described_class.select_and_initialize(listener, :use_polling => true)
        end
      end
    end

    context "on Linux" do
      before { Listen::Adapters::Linux.stub(:usable?) { true } }

      it "uses Listen::Adapters::Linux" do
        Listen::Adapters::Linux.should_receive(:new).with(listener)
        described_class.select_and_initialize(listener)
      end

      context 'when the use of the polling adapter is forced' do
        it 'uses Listen::Adapters::Polling' do
          Listen::Adapters::Polling.should_receive(:new).with(listener)
          described_class.select_and_initialize(listener, :use_polling => true)
        end
      end
    end
    context "on Windows" do
      before { Listen::Adapters::Windows.stub(:usable?) { true } }

      it "uses Listen::Adapters::Windows" do
        Listen::Adapters::Windows.should_receive(:new).with(listener)
        described_class.select_and_initialize(listener)
      end

      context 'when the use of the polling adapter is forced' do
        it 'uses Listen::Adapters::Polling' do
          Listen::Adapters::Polling.should_receive(:new).with(listener)
          described_class.select_and_initialize(listener, :use_polling => true)
        end
      end
    end
  end
end
