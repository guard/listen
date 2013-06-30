require 'spec_helper'

describe Listen::Adapter::Linux do
  if mac?
    it "isn't usable on OS X" do
      described_class.should_not be_usable
    end
  end

  if windows?
    it "isn't usable on Windows" do
      described_class.should_not be_usable
    end
  end

  if linux?
    let(:listener) { mock(Listen::Listener) }
    let(:adapter) { described_class.new(listener) }

    describe ".usable?" do
      it "returns always true" do
        described_class.should be_usable
      end
    end

    describe "#need_record?" do
      it "returns true" do
        adapter.need_record?.should be_true
      end
    end

    describe '#initialize' do
      it 'requires rb-inotify gem' do
        described_class.new(listener)
        require('rb-inotify').should be_false
      end
    end
  end

  if bsd?
    it "isn't usable on BSD" do
      described_class.should_not be_usable
    end
  end



  # if linux?
  #   if Listen::Adapter::Linux.usable?
  #     it "is usable on Linux" do
  #       described_class.should be_usable
  #     end

  #     it_should_behave_like 'a filesystem adapter'
  #     it_should_behave_like 'an adapter that call properly listener#on_change'

  #     describe '#initialize' do
  #       context 'when the inotify limit for watched files is not enough' do
  #         before { INotify::Notifier.any_instance.should_receive(:watch).and_raise(Errno::ENOSPC) }

  #         it 'fails gracefully' do
  #           described_class.any_instance.should_receive(:abort).with(described_class::INOTIFY_LIMIT_MESSAGE)
  #           described_class.new(File.dirname(__FILE__))
  #         end
  #       end
  #     end
  #   else
  #     it "isn't usable on Linux with #{RbConfig::CONFIG['RUBY_INSTALL_NAME']}" do
  #       described_class.should_not be_usable
  #     end
  #   end
  # end

  # if bsd?
  #   it "isn't usable on BSD" do
  #     described_class.should_not be_usable
  #   end
  # end

  # if mac?
  #   it "isn't usable on Mac OS X" do
  #     described_class.should_not be_usable
  #   end
  # end

  # if windows?
  #   it "isn't usable on Windows" do
  #     described_class.should_not be_usable
  #   end
  # end
end
