require 'spec_helper'

describe Listen::Adapter::Base do
  subject { described_class.new(listener) }

  let(:listener) { instance_double(Listen::Listener) }

  before { allow(listener).to receive(:async).with(:change_pool) { worker } }

  describe '#_notify_change' do
    context 'listener is listening or paused' do
      let(:worker) { instance_double(Listen::Change) }

      it 'calls change on change_pool asynchronously' do
        expect(worker).to receive(:change).
          with(:dir, 'path', recursive: true)
        subject.send(:_notify_change, :dir, 'path', recursive: true)
      end
    end

    context 'listener is stopped' do
      let(:worker) { nil }

      it 'does not fail when no worker is available' do
        expect(worker).to_not receive(:change)
        subject.send(:_notify_change, :dir, 'path', recursive: true)
      end
    end
  end
end
