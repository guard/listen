require 'spec_helper'

describe Listen::Adapter::BSD do

  if bsd?
    let(:listener) { double(Listen::Listener) }
    let(:adapter) { described_class.new(listener) }

    describe ".usable?" do
      it "returns always true" do
        expect(described_class).to be_usable
      end

      it 'requires rb-kqueue and find gem' do
        described_class.usable?
        expect(defined?(KQueue)).to be_true
        expect(defined?(Find)).to be_true
      end
    end
  end

  if darwin?
    it "isn't usable on Darwin" do
      expect(described_class).to_not be_usable
    end
  end

  if linux?
    it "isn't usable on Linux" do
      expect(described_class).to_not be_usable
    end
  end

  if windows?
    it "isn't usable on Windows" do
      expect(described_class).to_not be_usable
    end
  end
end
