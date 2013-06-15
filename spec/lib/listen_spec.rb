require 'spec_helper'

describe Listen do
  describe '#to' do
    it "initalizes listner" do
      Listen::Listener.should_receive(:new).with('/path')
      described_class.to('/path')
    end
  end
end
