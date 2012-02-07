require 'spec_helper'

describe Listen::Adapters::Darwin do
  if mac? && Listen::Adapters::Darwin.usable?
    it "is usable on Mac OS X >= 10.6" do
      described_class.should be_usable
    end

    it_should_behave_like "an adapter that call properly listener#on_change"
  end
  
  if windows?
    it "isn't usable on Windows" do
      described_class.should_not be_usable
    end
  end

  if linux?
    it "isn't usable on Linux" do
      described_class.should_not be_usable
    end
  end
end
