require 'listen/event/processor'
require 'listen/event/config'

RSpec.describe Listen::Event::Processor do
  let(:event_queue) { instance_double(::Queue, 'event_queue') }
  let(:config) { instance_double(Listen::Event::Config) }
  let(:reasons) { instance_double(::Queue, 'reasons') }

  subject { described_class.new(config, reasons) }

  # This is to simulate events over various points in time
  let(:sequence) do
    {}
  end

  let(:state) do
    { time: 0 }
  end

  def status_for_time(time)
    # find the status of the listener for a given point in time
    previous_state_timestamps = sequence.keys.reject { |k| k > time }
    last_state_before_given_time = previous_state_timestamps.max
    sequence[last_state_before_given_time]
  end

  before do
    allow(config).to receive(:event_queue).and_return(event_queue)

    allow(config).to receive(:stopped?) do
      status_for_time(state[:time]) == :stopped
    end

    allow(config).to receive(:paused?) do
      status_for_time(state[:time]) == :paused
    end

    allow(config).to receive(:timestamp) do
      state[:time]
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
          subject.loop_for(1)
        end

        it 'does not sleep' do
          expect(config).to_not receive(:sleep)
          t = Time.now
          subject.loop_for(1)
          diff = Time.now.to_f - t.to_f
          expect(diff).to be < 0.01
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
            expect(config).to receive(:sleep).once { state[:time] = 0.6 }
            subject.loop_for(1)
          end

          it 'breaks' do
            allow(config).to receive(:sleep).once { state[:time] = 0.6 }
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
                with(no_args) { |*_args| state[:time] += 0.6 }.ordered

              # pretend we slept for latency (now: 1.6 seconds since start)
              allow(config).to receive(:sleep).
                with(1.0) { |*_args| state[:time] += 1.0 }.ordered

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
                with(no_args) { |*_args| state[:time] += 2.0 }.ordered

              # second loop starts here (no sleep, coz recent events, but no
              # processing coz paused

              # pretend we were woken up at 3.6 seconds since start
              allow(config).to receive(:sleep).
                with(no_args) { |*_args| state[:time] += 3.0 }.ordered

              subject.loop_for(1)
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
              expect(config).to receive(:sleep).
                once { |*_args| state[:time] = 0.6 }

              subject.loop_for(1)
            end

            it 'breaks' do
              allow(config).to receive(:sleep).
                once { |*_args| state[:time] = 0.6 }

              expect(config).to_not receive(:call)
              subject.loop_for(1)
            end
          end
        end

        context 'when event queue has events' do
          before do
          end

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
              allow(event_queue).to receive(:pop).and_return(change)

              allow(config).to receive(:optimize_changes).with([change]).
                and_return(resulting_changes)

              final_changes = [['foo'], [], []]
              allow(config).to receive(:call) do |*changes|
                state[:time] = 4.0 # stopped
                expect(changes).to eq(final_changes)
              end

              subject.instance_variable_set(:@first_unprocessed_event_time, -3)
              subject.loop_for(1)
            end
          end

          #  context "when stopped after sleeping" do
          #    it "breaks from the loop" do
          #      pending "todo"
          #    end
          #  end
        end
      end
    end
  end
end
