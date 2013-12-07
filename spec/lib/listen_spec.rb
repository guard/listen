require 'spec_helper'

describe Listen do
  describe '.to' do
    it "initalizes listener" do
      expect(Listen::Listener).to receive(:new).with('/path')
      described_class.to('/path')
    end

    it "sets stopping at false" do
      allow(Listen::Listener).to receive(:new)
      Listen.to('/path')
      expect(Listen.stopping).to be_false
    end
  end

  describe '.stop' do
    it "stops all listeners" do
      Listen.stop
      expect(Listen.stopping).to be_true
    end
  end
end
