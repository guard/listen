require 'spec_helper'

describe Listen::Adapter do

  let(:listener) { double(Listen::Listener, options: {}) }
  before do
    Listen::Adapter::BSD.stub(:usable?) { false }
    Listen::Adapter::Darwin.stub(:usable?) { false }
    Listen::Adapter::Linux.stub(:usable?) { false }
    Listen::Adapter::Windows.stub(:usable?) { false }
  end

  describe '.select' do
    it 'returns TCP adapter when requested' do
      klass = Listen::Adapter.select(force_tcp: true)
      expect(klass).to eq Listen::Adapter::TCP
    end

    it 'returns Polling adapter if forced' do
      klass = Listen::Adapter.select(force_polling: true)
      expect(klass).to eq Listen::Adapter::Polling
    end

    it 'returns BSD adapter when usable' do
      Listen::Adapter::BSD.stub(:usable?) { true }
      klass = Listen::Adapter.select
      expect(klass).to eq Listen::Adapter::BSD
    end

    it 'returns Darwin adapter when usable' do
      Listen::Adapter::Darwin.stub(:usable?) { true }
      klass = Listen::Adapter.select
      expect(klass).to eq Listen::Adapter::Darwin
    end

    it 'returns Linux adapter when usable' do
      Listen::Adapter::Linux.stub(:usable?) { true }
      klass = Listen::Adapter.select
      expect(klass).to eq Listen::Adapter::Linux
    end

    it 'returns Windows adapter when usable' do
      Listen::Adapter::Windows.stub(:usable?) { true }
      klass = Listen::Adapter.select
      expect(klass).to eq Listen::Adapter::Windows
    end

    context 'no usable adapters' do
      before { Kernel.stub(:warn) }

      it 'returns Polling adapter' do
        klass = Listen::Adapter.select(force_polling: true)
        expect(klass).to eq Listen::Adapter::Polling
      end

      it 'warns polling fallback with default message' do
        msg = described_class::POLLING_FALLBACK_MESSAGE
        expect(Kernel).to receive(:warn).with("[Listen warning]:\n  #{msg}")
        Listen::Adapter.select
      end

      it "doesn't warn if polling_fallback_message is false" do
        expect(Kernel).to_not receive(:warn)
        Listen::Adapter.select(polling_fallback_message: false)
      end

      it 'warns polling fallback with custom message if set' do
        expected_msg = "[Listen warning]:\n  custom fallback message"
        expect(Kernel).to receive(:warn).with(expected_msg)
        msg = 'custom fallback message'
        Listen::Adapter.select(polling_fallback_message: msg)
      end
    end
  end
end
