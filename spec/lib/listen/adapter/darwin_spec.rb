require 'spec_helper'

describe Listen::Adapter::Darwin do
  if darwin?
    let(:listener) { double(Listen::Listener) }
    let(:adapter) { described_class.new(listener) }

    describe ".usable?" do
      it "returns always true" do
        expect(described_class).to be_usable
      end
    end

    describe '#initialize' do
      it 'requires rb-fsevent gem' do
        described_class.new(listener)
        expect(defined?(FSEvent)).to be_true
      end
    end
  end

  if windows?
    it "isn't usable on Windows" do
      expect(described_class).to_not be_usable
    end
  end

  if linux?
    it "isn't usable on Linux" do
      expect(described_class).to_not be_usable
    end
  end

  if bsd?
    it "isn't usable on BSD" do
      expect(described_class).to_not be_usable
    end
  end
end
