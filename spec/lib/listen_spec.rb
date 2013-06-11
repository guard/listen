require 'spec_helper'

describe Listen do
  describe '#to' do
    let(:listener)       { MockActor.new }
    let(:listener_class) { Listen::Listener }
    before { listener_class.stub(new: listener) }

    it "initalizes listner" do
      listener_class.should_receive(:new).with('/path')
      described_class.to('/path')
    end

    it "registries listener actor" do
      described_class.to('/path')
      Celluloid::Actor[:listener].should eq listener
    end

    it "calls listener start asynchronously " do
      # TODO
      described_class.to('/path')
      # Celluloid::Actor[:listener].should eq listener
    end
  end
end
