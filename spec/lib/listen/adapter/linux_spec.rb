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
        expect(defined?(INotify)).to be_true
      end
    end

    describe '_worker_callback' do

      let(:expect_change) {
        ->(change) {
          allow_any_instance_of(Listen::Adapter::Base).to receive(:_notify_change).with(Pathname.new('path/foo.txt'), type: 'File', change: change)
        }
      }

      let(:event_callback) {
        ->(flags) {
          callback = adapter.send(:_worker_callback)
          callback.call double(Pathname, name: 'foo.txt', flags: flags, absolute_name: 'path/foo.txt')
        }
      }

      # use case: close_write is the only way to detect changes
      # on ecryptfs
      it 'recognizes close_write as modify' do
        expect_change.(:modified)
        event_callback.([:close_write])
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
