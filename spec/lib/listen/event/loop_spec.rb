# frozen_string_literal: true

require 'thread'
require 'listen/event/config'
require 'listen/event/loop'

RSpec.describe Listen::Event::Loop do
  let(:config) { instance_double(Listen::Event::Config, 'config') }
  let(:processor) { instance_double(Listen::Event::Processor, 'processor') }
  let(:thread) { instance_double(Thread) }

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

    allow(Thread).to receive(:new) do |*_, &block|
      blocks[:thread_block] = block
      thread
    end

    allow(Kernel).to receive(:sleep) do |*args|
      fail "stub called: sleep(#{args.map(&:inspect) * ','})"
    end

    allow(subject).to receive(:_nice_error) do |ex|
      indent = "\n -- "
      backtrace = ex.backtrace.reject { |line| line =~ %r{\/gems\/} }
      fail "error called: #{ex}: #{indent}#{backtrace * indent}"
    end
  end

  describe '#start' do
    before do
      expect(Thread).to receive(:new) do |&block|
        block.call
        thread
      end

      expect(processor).to receive(:loop_for).with(1.234)

      subject.start
    end

    it 'is started' do
      expect(subject).to be_started
    end

    context 'when start is called again' do
      it 'returns silently' do
        expect { subject.start }.to_not raise_exception
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
        allow(thread).to receive_message_chain(:join, :kill)
      end

      it 'frees the thread' do
        subject.stop
      end

      it 'waits for the thread to finish' do
        expect(thread).to receive_message_chain(:join, :kill)
        subject.stop
      end

      it 'sets the reason for waking up' do
        subject.stop
      end
    end
  end
end
