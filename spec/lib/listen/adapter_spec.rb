require 'spec_helper'

describe Listen::Adapter do
  let(:listener) { MockActor.new }
  before {
    Celluloid::Actor[:listener] = listener
    Listen::Adapter::BSD.stub(:usable?) { false }
    Listen::Adapter::Darwin.stub(:usable?) { false }
    Listen::Adapter::Linux.stub(:usable?) { false }
    Listen::Adapter::Windows.stub(:usable?) { false }
  }

  describe ".new" do
    it "returns Polling adapter if forced" do
      listener.options[:force_polling] = true
      described_class.new.should be_kind_of Listen::Adapter::Polling
    end

    it "returns BSD adapter when usable" do
      Listen::Adapter::BSD.stub(:usable?) { true }
      described_class.new.should be_kind_of Listen::Adapter::BSD
    end

    it "returns Darwin adapter when usable" do
      Listen::Adapter::Darwin.stub(:usable?) { true }
      described_class.new.should be_kind_of Listen::Adapter::Darwin
    end

    it "returns Linux adapter when usable" do
      Listen::Adapter::Linux.stub(:usable?) { true }
      described_class.new.should be_kind_of Listen::Adapter::Linux
    end

    it "returns Windows adapter when usable" do
      Listen::Adapter::Windows.stub(:usable?) { true }
      described_class.new.should be_kind_of Listen::Adapter::Windows
    end

    context "no usable adapters" do
      before { Kernel.stub(:warn) }

      it "returns Polling adapter" do
        described_class.new.should be_kind_of Listen::Adapter::Polling
      end

      it "warns polling fallback with default message" do
        Kernel.should_receive(:warn).with("[Listen warning]:\n  #{described_class::POLLING_FALLBACK_MESSAGE}")
        described_class.new
      end

      it "doesn't warn if polling_fallback_message is false" do
        listener.options[:polling_fallback_message] = false
        Kernel.should_not_receive(:warn)
        described_class.new
      end

      it "warns polling fallback with custom message if set" do
        listener.options[:polling_fallback_message] = 'custom fallback message'
        Kernel.should_receive(:warn).with("[Listen warning]:\n  custom fallback message")
        described_class.new
      end
    end
  end
end
