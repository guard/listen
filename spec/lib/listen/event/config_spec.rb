# frozen_string_literal: true

require 'listen/event/config'

RSpec.describe Listen::Event::Config do
  let(:listener) { instance_double(Listen::Listener) }
  let(:event_queue) { instance_double(Listen::Event::Queue) }
  let(:queue_optimizer) { instance_double(Listen::QueueOptimizer) }
  let(:wait_for_delay) { 1.234 }

  context 'with a given block' do
    let(:myblock) { instance_double(Proc) }

    subject do
      described_class.new(
        listener,
        event_queue,
        queue_optimizer,
        wait_for_delay) do |*args|
          myblock.call(*args)
        end
    end

    it 'calls the block' do
      expect(myblock).to receive(:call).with(:foo, :bar)
      subject.call(:foo, :bar)
    end

    it 'is callable' do
      expect(subject).to be_callable
    end
  end
end
