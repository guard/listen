require 'spec_helper'

describe Listen::Adapters::Linux do
  if linux?
    if Listen::Adapters::Linux.usable?
      it "is usable on Linux" do
        described_class.should be_usable
      end

      it_should_behave_like 'a filesystem adapter'
      it_should_behave_like 'an adapter that call properly listener#on_change'
    else
      it "isn't usable on Linux with #{RbConfig::CONFIG['RUBY_INSTALL_NAME']}" do
        described_class.should_not be_usable
      end
    end
  end

  if mac?
    it "isn't usable on Mac OS X" do
      described_class.should_not be_usable
    end
  end

  if windows?
    it "isn't usable on Windows" do
      described_class.should_not be_usable
    end
  end
end
