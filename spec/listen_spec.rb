require 'spec_helper'

describe Listen do
  describe '#to' do
    let(:listener) { mock(Listen::Listener) }
    before { Listen::Listener.stub(:new).with("/path", :filter => '**/*') { listener } }

    context 'with a block' do
      it "returns a new listener created with the passed params" do
        Listen.to('/path', :filter => '**/*').should eq listener
      end
    end

    context 'without a block' do
      it 'starts a new listener after creating it with the passed params' do
        listener.should_receive(:start)
        Listen.to('/path', :filter => '**/*') { |modified, added, removed| }
      end
    end
  end

  describe "#to_each" do
    let(:multi_listener) { mock(Listen::MultiListener) }
    before { Listen::MultiListener.stub(:new).with('path1', 'path2', :filter => '**/*') { multi_listener } }

    context 'with a block' do
      it "returns a new listener created with the passed params" do
        Listen.to_each('path1', 'path2', :filter => '**/*').should eq multi_listener
      end
    end

    context 'without a block' do
      it 'starts a new listener after creating it with the passed params' do
        multi_listener.should_receive(:start)
        Listen.to_each('path1', 'path2', :filter => '**/*') { |modified, added, removed| }
      end
    end
  end
end
