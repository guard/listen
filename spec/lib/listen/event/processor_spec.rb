# frozen_string_literal: true

require 'listen/event/processor'
require 'listen/event/config'

RSpec.describe Listen::Event::Processor do
  let(:event_queue) { instance_double(::Queue, 'event_queue') }
  let(:event) { instance_double(::Array, 'event') }
  let(:listener) { instance_double(Listen::Listener, 'listener') }
  let(:config) { instance_double(Listen::Event::Config, 'config', listener: listener) }
  let(:reasons) { instance_double(::Queue, 'reasons') }

  subject { described_class.new(config, reasons) }

  # This is to simulate events over various points in time
  let(:sequence) do
    {}
  end

  let(:state) do
    { monotonic_time: 0.0 }
  end

  def status_for_time(time)
    # find the status of the listener for a given point in time
    previous_state_timestamps = sequence.keys.reject { |k| k > time }
    last_state_before_given_time = previous_state_timestamps.max
    sequence[last_state_before_given_time]
  end

  before do
    allow(config).to receive(:event_queue).and_return(event_queue)

    allow(listener).to receive(:stopped?) do
      status_for_time(state[:monotonic_time]) == :stopped
    end

    allow(listener).to receive(:paused?) do
      status_for_time(state[:monotonic_time]) == :paused
    end

    allow(Listen::MonotonicTime).to receive(:now) do
      state[:monotonic_time]
    end
  end

  describe '#loop_for' do
    before do
      allow(reasons).to receive(:empty?).and_return(true)
    end

    context 'when stopped' do
      before do
        sequence[0.0] = :stopped
      end

      context 'with pending changes' do
        before do
          allow(event_queue).to receive(:empty?).and_return(false)
        end

        it 'does not change the event queue' do
          expect(event_queue).to receive(:pop).and_return(event)
          subject.loop_for(1)
        end

        it 'does not sleep' do
          expect(config).to_not receive(:sleep)
          expect(event_queue).to receive(:pop).and_return(event)
          t = Listen::MonotonicTime.now
          subject.loop_for(1)
          diff = Listen::MonotonicTime.now - t
          expect(diff).to be < 0.02
        end
      end
    end

    context 'when not stopped' do
      before do
        allow(event_queue).to receive(:empty?).and_return(true)
      end

      context 'when initially paused' do
        before do
          sequence[0.0] = :paused
        end

        context 'when stopped after sleeping' do
          before do
            sequence[0.2] = :stopped
          end

          it 'sleeps, waiting to be woken up' do
            expect(config).to receive(:sleep).once { state[:monotonic_time] = 0.6 }
            expect(event_queue).to receive(:pop).and_return(event)
            subject.loop_for(1)
          end

          it 'breaks' do
            expect(event_queue).to receive(:pop).and_return(event)
            allow(config).to receive(:sleep).once { state[:monotonic_time] = 0.6 }
            expect(config).to_not receive(:call)
            subject.loop_for(1)
          end
        end

        context 'when still paused after sleeping' do
          context 'when there were no events before' do
            before do
              sequence[1.0] = :stopped
            end

            it 'sleeps for latency to possibly later optimize some events' do
              # pretend we were woken up at 0.6 seconds since start
              allow(config).to receive(:sleep).
                with(anything) { |*_args| state[:monotonic_time] += 0.6 }

              # pretend we slept for latency (now: 1.6 seconds since start)
              allow(config).to receive(:sleep).
                with(1.0) { |*_args| state[:monotonic_time] += 1.0 }

              expect(event_queue).to receive(:pop).and_return(event)
              subject.loop_for(1)
            end
          end

          context 'when there were no events for ages' do
            before do
              sequence[3.5] = :stopped # in the future to break from the loop
            end

            it 'still does not process events because it is paused' do
              # pretend we were woken up at 0.6 seconds since start
              allow(config).to receive(:sleep).
                with(anything) { |*_args| state[:monotonic_time] += 2.0 }

              # second loop starts here (no sleep, coz recent events, but no
              # processing coz paused

              # pretend we were woken up at 3.6 seconds since start
              allow(listener).to receive(:wait_for_state).
                with(:initializing, :backend_started, :processing_events, :stopped) do |*_args|
                state[:monotonic_time] += 3.0
                raise ScriptError, 'done'
              end

              expect(event_queue).to receive(:pop).and_return(event)
              expect { subject.loop_for(1) }.to raise_exception(ScriptError, 'done')
            end
          end
        end
      end

      context 'when initially processing' do
        before do
          sequence[0.0] = :processing
        end

        context 'when event queue is empty' do
          before do
            allow(event_queue).to receive(:empty?).and_return(true)
          end

          context 'when stopped after sleeping' do
            before do
              sequence[0.2] = :stopped
            end

            it 'sleeps, waiting to be woken up' do
              expect(event_queue).to receive(:pop).and_return(event)
              expect(config).to receive(:sleep).
                once { |*_args| state[:monotonic_time] = 0.6 }

              subject.loop_for(1)
            end

            it 'breaks' do
              allow(config).to receive(:sleep).
                once { |*_args| state[:monotonic_time] = 0.6 }

              expect(config).to_not receive(:call)
              expect(event_queue).to receive(:pop).and_return(event)
              subject.loop_for(1)
            end
          end
        end

        context 'when event queue has events' do
          context 'when there were events ages ago' do
            before do
              sequence[3.5] = :stopped # in the future to break from the loop
            end

            it 'processes events' do
              allow(event_queue).to receive(:empty?).
                and_return(false, false, true)

              # resets latency check
              expect(config).to receive(:callable?).and_return(true)

              change = [:file, :modified, 'foo', 'bar']
              resulting_changes = { modified: ['foo'], added: [], removed: [] }
              allow(event_queue).to receive(:pop).and_return(change).exactly(4)

              allow(config).to receive(:optimize_changes).with([change, change, change]).
                and_return(resulting_changes)

              final_changes = [['foo'], [], []]
              allow(config).to receive(:call) do |*changes|
                state[:monotonic_time] = 4.0 # stopped
                expect(changes).to eq(final_changes)
              end

              allow(listener).to receive(:wait_for_state).
                with(:initializing, :backend_started, :processing_events, :stopped)

              subject.instance_variable_set(:@_remember_time_of_first_unprocessed_event, -3)
              subject.loop_for(1)
            end
          end
        end
      end
    end
  end

  describe '_process_changes' do
    context 'when it raises an exception derived from StandardError' do
      before do
        allow(event_queue).to receive(:empty?).and_return(true)
        allow(config).to receive(:callable?).and_return(true)
        resulting_changes = { modified: ['foo'], added: [], removed: [] }
        allow(config).to receive(:optimize_changes).with(anything).and_return(resulting_changes)
        expect(config).to receive(:call).and_raise(ArgumentError, "bang!")
        expect(config).to receive(:call).and_return(nil)
        expect(config).to receive(:call).and_raise("error!")
      end

      it 'rescues and logs exception and continues' do
        expect(Listen.logger).to receive(:error).with(/Exception rescued in _process_changes:\nArgumentError: bang!/)
        expect(Listen.logger).to receive(:error).with(/Exception rescued in _process_changes:\nRuntimeError: error!/)
        expect(Listen.logger).to receive(:debug).with(/Callback \(exception\) took/)
        expect(Listen.logger).to receive(:debug).with(/Callback took/)
        expect(Listen.logger).to receive(:debug).with(/Callback \(exception\) took/)
        subject.send(:_process_changes, event)
        subject.send(:_process_changes, event)
        subject.send(:_process_changes, event)
      end
    end
  end
end
