require 'spec_helper'

describe Listen::Turnstile do
  describe '#wait' do
    context 'without a signal' do
      it 'blocks one thread indefinitely' do
        called = false
        t1 = Thread.new { subject.wait; called = true }
        t2 = Thread.new { sleep ENV["TEST_LATENCY"]; Thread.kill t1 }
        t2.join
        called.should be_false
      end
    end

    context 'with a signal' do
      it 'blocks one thread until it recieves a signal from another thread' do
        called = false
        t1 = Thread.new { subject.wait; called = true }
        t2 = Thread.new { subject.signal; sleep ENV["TEST_LATENCY"]; Thread.kill t1 }
        t2.join
        called.should be_true
      end
    end
  end

  describe '#signal' do
    context 'without a wait-call before' do
      it 'does nothing' do
        called = false
        t1 = Thread.new { subject.signal; called = true }
        t2 = Thread.new { sleep ENV["TEST_LATENCY"]; Thread.kill t1 }
        t2.join
        called.should be_true
      end
    end
  end
end
