require 'spec_helper'

describe Listen::Adapter do
  let(:listener) { mock(Listen::Listener) }
  before do
    Listen::Adapters::Darwin.stub(:usable?) { false }
    Listen::Adapters::Linux.stub(:usable?) { false }
  end

  describe ".select_and_initialize" do
    context "with no specific adapter usable" do
      it "returns Listen::Adapters::Polling instance" do
        Listen::Adapters::Polling.should_receive(:new).with(listener)
        described_class.select_and_initialize(listener)
      end
    end
    context "on Mac OX >= 10.6" do
      before { Listen::Adapters::Darwin.stub(:usable?) { true } }

      it "uses Listen::Adapters::Darwin" do
        Listen::Adapters::Darwin.should_receive(:new).with(listener)
        described_class.select_and_initialize(listener)
      end
    end
    context "on Linux" do
      before { Listen::Adapters::Linux.stub(:usable?) { true } }

      it "uses Listen::Adapters::Linux" do
        Listen::Adapters::Linux.should_receive(:new).with(listener)
        described_class.select_and_initialize(listener)
      end
    end
  end
end
