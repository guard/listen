# frozen_string_literal: true

RSpec.describe Listen do
  let(:listener) { instance_double(Listen::Listener, stop: nil) }

  after do
    Listen.stop
  end

  describe '.to' do
    it 'initalizes listener' do
      expect(Listen::Listener).to receive(:new).with('/path') { listener }
      described_class.to('/path')
    end
  end

  describe '.stop' do
    it 'stops all listeners' do
      allow(Listen::Listener).to receive(:new).with('/path') { listener }
      expect(listener).to receive(:stop)
      described_class.to('/path')
      Listen.stop
    end
  end
end
