require 'spec_helper'

describe Listen::Adapter do
  let(:listener) { mock(Listen::Listener, :directory => 'path') }

  describe ".select_and_initialize" do
    context "on Mac OX < 10.6" do
      before { RbConfig::CONFIG.stub!(:[]).with('target_os') { 'darwin9.0.0' } }

      it "returns Listen::Adapters::Polling instance" do
        described_class.select_and_initialize(listener).should be_an_instance_of(Listen::Adapters::Polling)
      end
    end
    context "on Mac OX >= 10.6" do
      before { RbConfig::CONFIG.stub!(:[]).with('target_os') { 'darwin10.0.0' } }

      it "returns Listen::Adapters::Darwin instance" do
        described_class.select_and_initialize(listener).should be_an_instance_of(Listen::Adapters::Darwin)
      end
    end

  end

end
