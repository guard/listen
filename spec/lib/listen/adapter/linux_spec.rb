require 'spec_helper'

describe Listen::Adapter::Linux do
  if linux?
    let(:listener) { double(Listen::Listener) }
    let(:adapter) { described_class.new(listener) }

    describe ".usable?" do
      it "returns always true" do
        expect(described_class).to be_usable
      end
    end

    describe '#initialize' do
      it 'requires rb-inotify gem' do
        described_class.new(listener)
        expect(require('rb-inotify')).to be_false
      end
    end
  end

  if darwin?
    it "isn't usable on Darwin" do
      expect(described_class).to_not be_usable
    end
  end

  if windows?
    it "isn't usable on Windows" do
      expect(described_class).to_not be_usable
    end
  end

  if bsd?
    it "isn't usable on BSD" do
      expect(described_class).to_not be_usable
    end
  end
end
