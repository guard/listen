require 'spec_helper'

describe Listen do
  describe '#to' do
    it "initalizes listner" do
      expect(Listen::Listener).to receive(:new).with('/path')
      described_class.to('/path')
    end
  end
end
