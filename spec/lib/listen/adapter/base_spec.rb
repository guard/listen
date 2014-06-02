require 'spec_helper'

include Listen

describe Adapter::Base do

  class FakeAdapter < described_class
    def initialize(*args)
      super(*args)
    end
  end

  subject { FakeAdapter.new(mq: listener, directories: []) }

  let(:listener) { instance_double(Listener) }

  before { allow(listener).to receive(:async).with(:change_pool) { worker } }

  describe '#_notify_change' do
    context 'listener is listening or paused' do
      let(:worker) { instance_double(Change) }

      it 'calls change on change_pool asynchronously' do
        expect(worker).to receive(:change).
          with(:dir, 'path', recursive: true)
        subject.send(:_notify_change, :dir, 'path', recursive: true)
      end
    end

    context 'listener is stopped' do
      let(:worker) { nil }

      it 'does not fail when no worker is available' do
        expect do
          subject.send(:_notify_change, :dir, 'path', recursive: true)
        end.to_not raise_error
      end
    end
  end
end
