require 'spec_helper'

describe Listen::Adapter do
  subject { described_class.new('dir') }
  before do
    Listen::Adapters::Darwin.stub(:usable_and_work?) { false }
    Listen::Adapters::Linux.stub(:usable_and_work?) { false }
    Listen::Adapters::Windows.stub(:usable_and_work?) { false }
  end

  describe '#initialize' do
    it 'sets the latency to the default one' do
      subject.latency.should eq described_class::DEFAULT_LATENCY
    end
  end

  describe ".select_and_initialize" do
    context "with no specific adapter usable" do
      it "returns Listen::Adapters::Polling instance" do
        Kernel.stub(:warn)
        Listen::Adapters::Polling.should_receive(:new).with('dir', {})
        described_class.select_and_initialize('dir')
      end

      it "warns with the default polling fallback message" do
        Kernel.should_receive(:warn).with(Listen::Adapter::POLLING_FALLBACK_MESSAGE)
        described_class.select_and_initialize('dir')
      end

      context "with custom polling_fallback_message option" do
        it "warns with the custom polling fallback message" do
          Kernel.should_receive(:warn).with('custom')
          described_class.select_and_initialize('dir', :polling_fallback_message => 'custom')
        end
      end

      context "with polling_fallback_message to false" do
        it "doesn't warn with a polling fallback message" do
          Kernel.should_not_receive(:warn)
          described_class.select_and_initialize('dir', :polling_fallback_message => false)
        end
      end
    end

    context "on Mac OX >= 10.6" do
      before { Listen::Adapters::Darwin.stub(:usable_and_work?) { true } }

      it "uses Listen::Adapters::Darwin" do
        Listen::Adapters::Darwin.should_receive(:new).with('dir', {})
        described_class.select_and_initialize('dir')
      end

      context 'when the use of the polling adapter is forced' do
        it 'uses Listen::Adapters::Polling' do
          Listen::Adapters::Polling.should_receive(:new).with('dir', {})
          described_class.select_and_initialize('dir', :force_polling => true)
        end
      end
    end

    context "on Linux" do
      before { Listen::Adapters::Linux.stub(:usable_and_work?) { true } }

      it "uses Listen::Adapters::Linux" do
        Listen::Adapters::Linux.should_receive(:new).with('dir', {})
        described_class.select_and_initialize('dir')
      end

      context 'when the use of the polling adapter is forced' do
        it 'uses Listen::Adapters::Polling' do
          Listen::Adapters::Polling.should_receive(:new).with('dir', {})
          described_class.select_and_initialize('dir', :force_polling => true)
        end
      end
    end
    context "on Windows" do
      before { Listen::Adapters::Windows.stub(:usable_and_work?) { true } }

      it "uses Listen::Adapters::Windows" do
        Listen::Adapters::Windows.should_receive(:new).with('dir', {})
        described_class.select_and_initialize('dir')
      end

      context 'when the use of the polling adapter is forced' do
        it 'uses Listen::Adapters::Polling' do
          Listen::Adapters::Polling.should_receive(:new).with('dir', {})
          described_class.select_and_initialize('dir', :force_polling => true)
        end
      end
    end
  end

  [Listen::Adapters::Darwin, Listen::Adapters::Linux, Listen::Adapters::Windows].each do |adapter_class|
    if adapter_class.usable?
      describe ".work?" do
        it "does work" do
          fixtures do |path|
            adapter_class.work?(path).should be_true
          end
        end
      end
    end
  end

end
