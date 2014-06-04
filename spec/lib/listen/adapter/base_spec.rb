require 'spec_helper'

include Listen

describe Adapter::Base do

  class FakeAdapter < described_class
    def initialize(*args)
      super(*args)
    end
  end

  subject { FakeAdapter.new(mq: mq, directories: []) }

  let(:mq) { instance_double(Listener) }

  describe '#_notify_change' do
    let(:dir) { Pathname.pwd }

    context 'listener is listening or paused' do
      let(:worker) { instance_double(Change) }

      it 'calls change on change_pool asynchronously' do
        expect(mq).to receive(:_queue_raw_change).
          with(:dir, dir, 'path', recursive: true)

        subject.send(:_queue_change, :dir, dir, 'path', recursive: true)
      end
    end
  end
end
