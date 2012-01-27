require 'spec_helper'

describe Listen do

  describe "#to" do
    let(:listener) { mock(Listen::Listener) }
    before { Listen::Listener.stub(:new).with("/path", :filter => '**/*') { listener } }

    context "with a block" do
      it "returns a new listener created with good params" do
        Listen.to('/path', :filter => '**/*').should eq listener
      end
    end

    context "without a block" do
      it "starts the new listener created with good" do
        listener.should_receive(:start)
        Listen.to('/path', :filter => '**/*') { |modified, added, removed| }
      end
    end

  end

end
