# frozen_string_literal: true

require 'thread'
require 'listen/event/config'
require 'listen/event/loop'

RSpec.describe Listen::Event::Loop do
  let(:config) { instance_double(Listen::Event::Config, 'config') }
  let(:processor) { instance_double(Listen::Event::Processor, 'processor') }
  let(:thread) { instance_double(Thread, 'thread') }

  let(:reasons) { instance_double(::Queue, 'reasons') }
  let(:ready) { instance_double(::Queue, 'ready') }

  let(:blocks) do
    {
      thread_block: proc { fail 'thread block stub called' },
    }
  end

  subject { described_class.new(config) }

  # TODO: this is hideous
  before do
    allow(::Queue).to receive(:new).and_return(reasons, ready)
    allow(Listen::Event::Processor).to receive(:new).with(config, reasons).
      and_return(processor)

    allow(Thread).to receive(:new) do |*args, &block|
      fail 'Unstubbed call:'\
        " Thread.new(#{args.map(&:inspect) * ','},&#{block.inspect})"
    end

    allow(config).to receive(:min_delay_between_events).and_return(1.234)

    allow(thread).to receive(:name=)
    allow(Thread).to receive(:new) do |*_, &block|
      blocks[:thread_block] = block
      thread
    end

    allow(Kernel).to receive(:sleep) do |*args|
      fail "stub called: sleep(#{args.map(&:inspect) * ','})"
    end
  end

  describe '#start' do
    it 'is started' do
      expect(processor).to receive(:loop_for).with(1.234)
      expect(Thread).to receive(:new) do |&block|
        block.call
        thread
      end
      subject.start
      expect(subject).to be_started
    end

    context 'when start is called again' do
      it 'returns silently' do
        expect(processor).to receive(:loop_for).with(1.234)
        expect(Thread).to receive(:new) do |&block|
          block.call
          thread
        end
        subject.start
        expect { subject.start }.to_not raise_exception
      end
    end

    context 'when state change to :started takes longer than 5 seconds' do
      before do
        expect(Thread).to receive(:new) { thread }
        expect_any_instance_of(::ConditionVariable).to receive(:wait) { } # return immediately
      end

      it 'raises Error::NotStarted' do
        expect do
          subject.start
        end.to raise_exception(::Listen::Error::NotStarted, "thread didn't start in 5.0 seconds (in state: :starting)")
      end
    end
  end

  context 'when set up / started' do
    before do
      allow(thread).to receive(:alive?).and_return(true)
      allow(config).to receive(:min_delay_between_events).and_return(1.234)

      allow(processor).to receive(:loop_for).with(1.234)

      expect(Thread).to receive(:new) do |&block|
        block.call
        thread
      end

      subject.start
    end

    describe '#stop' do
      before do
        allow(thread).to receive(:join)
      end

      it 'frees the thread' do
        subject.stop
      end

      it 'waits for the thread to finish' do
        expect(thread).to receive(:join)
        subject.stop
      end

      it 'sets the reason for waking up' do
        subject.stop
      end
    end
  end
end
