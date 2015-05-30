RSpec.describe Listen::Adapter do

  let(:listener) { instance_double(Listen::Listener, options: {}) }
  before do
    allow(Listen::Adapter::BSD).to receive(:usable?) { false }
    allow(Listen::Adapter::Darwin).to receive(:usable?) { false }
    allow(Listen::Adapter::SimulatedDarwin).to receive(:usable?) { false }
    allow(Listen::Adapter::Linux).to receive(:usable?) { false }
    allow(Listen::Adapter::Windows).to receive(:usable?) { false }
  end

  describe '.select' do
    let(:options) { {} }
    subject { Listen::Adapter.select(options) }

    context "when on Darwin" do
      before { allow(Listen::Adapter::Darwin).to receive(:usable?) { true } }

      it { is_expected.to be Listen::Adapter::Darwin }

      context "when TCP is requested" do
        let(:options) { { force_tcp: true } }
        it { is_expected.to be Listen::Adapter::TCP }
      end

      context "when polling is forced" do
        let(:options) { { force_polling: true } }
        it { is_expected.to be Listen::Adapter::Polling }
      end
    end

    context "when on BSD" do
      before { allow(Listen::Adapter::BSD).to receive(:usable?) { true } }

      it { is_expected.to be Listen::Adapter::BSD }

      context "when TCP is requested" do
        let(:options) { { force_tcp: true } }
        it { is_expected.to be Listen::Adapter::TCP }
      end

      context "when polling is forced" do
        let(:options) { { force_polling: true } }
        it { is_expected.to be Listen::Adapter::Polling }
      end
    end

    context "when on Linux" do
      before { allow(Listen::Adapter::Linux).to receive(:usable?) { true } }

      context "when simulation mode is on" do
        before do
          allow(Listen::Adapter::SimulatedDarwin).to receive(:usable?) { true }
        end
        it { is_expected.to be Listen::Adapter::SimulatedDarwin }
      end

      context "when simulation mode is off" do
        before do
          allow(Listen::Adapter::SimulatedDarwin).to receive(:usable?) { false }
        end
        it { is_expected.to be Listen::Adapter::Linux }
      end

      context "when TCP is requested" do
        let(:options) { { force_tcp: true } }
        it { is_expected.to be Listen::Adapter::TCP }
      end

      context "when polling is forced" do
        let(:options) { { force_polling: true } }
        it { is_expected.to be Listen::Adapter::Polling }
      end
    end

    context "when on Windows" do
      before do
        allow(Listen::Adapter::Windows).to receive(:usable?) { true }
      end

      it { is_expected.to be Listen::Adapter::Windows }

      context "when TCP is requested" do
        let(:options) { { force_tcp: true } }
        it { is_expected.to be Listen::Adapter::TCP }
      end

      context "when polling is forced" do
        let(:options) { { force_polling: true } }
        it { is_expected.to be Listen::Adapter::Polling }
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
