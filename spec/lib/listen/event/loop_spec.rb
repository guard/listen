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

  context 'when stopped' do
    context 'when wakeup_on_event is called' do
      it 'does nothing' do
        subject.wakeup_on_event
      end
    end
  end

  describe '#start' do
    before do
      expect(Listen::Internals::ThreadPool).to receive(:add) do |*_, &block|
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
      it 'raises AlreadyStarted' do
        expect { subject.start }.to raise_exception(Listen::Event::Loop::Error::AlreadyStarted)
      end
    end

    context 'when wakeup_on_event is called' do
      let(:epoch) { 1234 }

      context 'when thread is alive' do
        before do
          allow(reasons).to receive(:<<)
          allow(thread).to receive(:alive?).and_return(true)
        end

        it 'wakes up the thread' do
          expect(thread).to receive(:wakeup)
          expect(subject.instance_variable_get(:@state)).to eq(:started)
          subject.wakeup_on_event
        end

        it 'sets the reason for waking up' do
          expect(thread).to receive(:wakeup)
          expect(reasons).to receive(:<<).with(:event)
          subject.wakeup_on_event
        end
      end

      context 'when thread is dead' do
        before do
          allow(thread).to receive(:alive?).and_return(false)
        end

        it 'does not wake up the thread' do
          expect(thread).to_not receive(:wakeup)
          subject.wakeup_on_event
        end
      end
    end
  end

  context 'when set up / started' do
    before do
      allow(thread).to receive(:alive?).and_return(true)
      allow(config).to receive(:min_delay_between_events).and_return(1.234)

      allow(processor).to receive(:loop_for).with(1.234)

      expect(Listen::Internals::ThreadPool).to receive(:add) do |*_, &block|
        block.call
        thread
      end

      subject.start
    end

    describe '#teardown' do
      before do
        allow(reasons).to receive(:<<)
        allow(thread).to receive_message_chain(:join, :kill)
        expect(thread).to receive(:wakeup)
      end

      it 'frees the thread' do
        subject.teardown
      end

      it 'waits for the thread to finish' do
        expect(thread).to receive_message_chain(:join, :kill)
        subject.teardown
      end

      it 'sets the reason for waking up' do
        expect(reasons).to receive(:<<).with(:teardown)
        subject.teardown
      end
    end
  end
end
