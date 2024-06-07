# frozen_string_literal: true

RSpec.describe Listen::Adapter do
  before do
    allow(Listen::Adapter::BSD).to receive(:usable?) { false }
    allow(Listen::Adapter::Darwin).to receive(:usable?) { false }
    allow(Listen::Adapter::Linux).to receive(:usable?) { false }
    allow(Listen::Adapter::ProcessLinux).to receive(:usable?) { false }
    allow(Listen::Adapter::Windows).to receive(:usable?) { false }
  end

  describe '.select' do
    shared_examples 'chooses usable' do
      let(:options) { {} }

      it 'returns Polling adapter if forced' do
        klass = Listen::Adapter.select(options.merge(force_polling: true))
        expect(klass).to eq Listen::Adapter::Polling
      end

      it 'returns BSD adapter when usable' do
        allow(Listen::Adapter::BSD).to receive(:usable?) { true }
        klass = Listen::Adapter.select(options)
        expect(klass).to eq Listen::Adapter::BSD
      end

      it 'returns Darwin adapter when usable' do
        allow(Listen::Adapter::Darwin).to receive(:usable?) { true }
        klass = Listen::Adapter.select(options)
        expect(klass).to eq Listen::Adapter::Darwin
      end

      it 'returns Linux adapter when usable' do
        allow(Listen::Adapter::Linux).to receive(:usable?) { true }
        klass = Listen::Adapter.select(options)
        expect(klass).to eq Listen::Adapter::Linux
      end

      it 'returns Windows adapter when usable' do
        allow(Listen::Adapter::Windows).to receive(:usable?) { true }
        klass = Listen::Adapter.select(options)
        expect(klass).to eq Listen::Adapter::Windows
      end
    end

    it_behaves_like 'chooses usable'
    it_behaves_like 'chooses usable' do
      let(:options) { { prefer_fork: true } }

      it 'returns ProcessLinux adapter when forks are preferred' do
        allow(Listen::Adapter::Linux).to receive(:usable?) { true }
        allow(Listen::Adapter::ProcessLinux).to receive(:usable?) { true }
        klass = Listen::Adapter.select(options)
        expect(klass).to eq Listen::Adapter::ProcessLinux
      end
    end

    context 'no usable adapters' do
      before { allow(Kernel).to receive(:warn) }

      it 'returns Polling adapter' do
        klass = Listen::Adapter.select(force_polling: true)
        expect(klass).to eq Listen::Adapter::Polling
      end

      it 'warns polling fallback with default message' do
        msg = described_class::POLLING_FALLBACK_MESSAGE
        expect(Listen).to receive(:adapter_warn).with("[Listen warning]:\n  #{msg}")
        Listen::Adapter.select
      end

      it "doesn't warn if polling_fallback_message is false" do
        expect(Kernel).to_not receive(:warn)
        Listen::Adapter.select(polling_fallback_message: false)
      end

      it 'warns polling fallback with custom message if set' do
        expected_msg = "[Listen warning]:\n  custom fallback message"
        expect(Listen).to receive(:adapter_warn).with(expected_msg)
        msg = 'custom fallback message'
        Listen::Adapter.select(polling_fallback_message: msg)
      end
    end
  end
end
