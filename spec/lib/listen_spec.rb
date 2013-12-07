require 'spec_helper'

describe Listen do
  describe '.to' do
    it "initalizes listener" do
      expect(Listen::Listener).to receive(:new).with('/path')
      described_class.to('/path')
    end
  end

  describe '.stop' do
    it "stops all listeners" do
      expect { Listen.stop }.to change(Listen, :stopping).from(nil).to(true)
    end
  end

end
