require 'spec_helper'

describe Listen::Adapter::Darwin do
  if mac?
    describe ".usable?" do
      it "returns always true" do
        described_class.should be_usable
      end
    end

    describe '#initialize' do
      it 'requires rb-fsevent gem' do
        described_class.new
        require('rb-fsevent').should be_false
      end
    end

    # it_should_behave_like 'an adapter that call properly notify listener on changes'
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

  if bsd?
    it "isn't usable on BSD" do
      described_class.should_not be_usable
    end
  end
end
