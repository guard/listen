require 'spec_helper'

describe Listen::Adapter do
  let(:adapter) { Listen::Adapter.new(listener) }
  let(:listener) { double(Listen::Listener, options: {}) }
  before {
    Listen::Adapter::BSD.stub(:usable?) { false }
    Listen::Adapter::Darwin.stub(:usable?) { false }
    Listen::Adapter::Linux.stub(:usable?) { false }
    Listen::Adapter::Windows.stub(:usable?) { false }
  }

  describe ".new" do
    it "returns Polling adapter if forced" do
      listener.stub(:options) { { force_polling: true } }
      expect(adapter).to be_kind_of Listen::Adapter::Polling
    end

    it "returns Polling adapter if not on MRI" do
      stub_const("RUBY_ENGINE", 'foo')
      Listen::Adapter::Linux.stub(:usable?) { true }
      expect(adapter).to be_kind_of Listen::Adapter::Polling
    end

    it "returns BSD adapter when usable" do
      Listen::Adapter::BSD.stub(:usable?) { true }
      Listen::Adapter::BSD.should_receive(:new)
      adapter
    end

    it "returns Darwin adapter when usable" do
      Listen::Adapter::Darwin.stub(:usable?) { true }
      Listen::Adapter::Darwin.should_receive(:new)
      adapter
    end

    it "returns Linux adapter when usable" do
      Listen::Adapter::Linux.stub(:usable?) { true }
      Listen::Adapter::Linux.should_receive(:new)
      adapter
    end

    it "returns Windows adapter when usable" do
      Listen::Adapter::Windows.stub(:usable?) { true }
      Listen::Adapter::Windows.should_receive(:new)
      adapter
    end

    context "no usable adapters" do
      before { Kernel.stub(:warn) }

      it "returns Polling adapter" do
        adapter.should be_kind_of Listen::Adapter::Polling
      end

      it "warns polling fallback with default message" do
        Kernel.should_receive(:warn).with("[Listen warning]:\n  #{described_class::POLLING_FALLBACK_MESSAGE}")
        adapter
      end

      it "doesn't warn if polling_fallback_message is false" do
        listener.stub(:options) { { polling_fallback_message: false } }
        Kernel.should_not_receive(:warn)
        adapter
      end

      it "warns polling fallback with custom message if set" do
        listener.stub(:options) { { polling_fallback_message: 'custom fallback message' } }
        Kernel.should_receive(:warn).with("[Listen warning]:\n  custom fallback message")
        adapter
      end
    end
  end
end
