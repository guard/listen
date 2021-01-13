# frozen_string_literal: true

RSpec.describe Listen::FSM do
  context 'simple FSM' do
    class SpecSimpleFsm
      include Listen::FSM

      attr_reader :entered_started

      start_state :initial

      state :started, to: :stopped do
        @entered_started = true
      end

      state :failed, to: :stopped

      state :stopped

      def start
        transition(:started)
      end

      def stop
        transition(:stopped)
      end

      def fail
        transition(:failed)
      end

      def initialize
        initialize_fsm
      end
    end

    subject(:fsm) { SpecSimpleFsm.new }

    it 'starts in start_state' do
      expect(subject.state).to eq(:initial)
    end

    it 'allows transitions' do
      subject.start
      expect(subject.state).to eq(:started)
      expect(subject.entered_started).to eq(true)
    end

    it 'raises on disallowed transitions' do
      subject.fail
      expect do
        subject.start
      end.to raise_exception(ArgumentError,
                             "SpecSimpleFsm can't change state from 'failed' to 'started', only to: stopped")
      expect(subject.state).to eq(:failed)
      expect(subject.entered_started).to eq(nil)
    end

    it 'declares transition and transition! private' do
      expect { subject.transition(:started) }.to raise_exception(NoMethodError, /private.*transition/)
      expect { subject.transition!(:started) }.to raise_exception(NoMethodError, /private.*transition!/)
    end

    describe '#wait_for_state' do
      it 'returns truthy immediately if already in the desired state' do
        expect(subject.instance_variable_get(:@state_changed)).to_not receive(:wait)
        result = subject.wait_for_state(:initial)
        expect(result).to be_truthy
      end

      it 'waits for the next state change and returns truthy if then in the desired state' do
        expect(subject.instance_variable_get(:@state_changed)).to receive(:wait).with(anything, anything) do
          subject.instance_variable_set(:@state, :started)
        end
        result = subject.wait_for_state(:started)
        expect(result).to be_truthy
      end

      it 'waits for the next state change and returns falsey if then not the desired state' do
        expect(subject.instance_variable_get(:@state_changed)).to receive(:wait).with(anything, anything)
        result = subject.wait_for_state(:started)
        expect(result).to be_falsey
      end

      it 'passes the timeout: down to wait, if given' do
        expect(subject.instance_variable_get(:@state_changed)).to receive(:wait).with(anything, 5.0)
        subject.wait_for_state(:started, timeout: 5.0)
      end

      it 'passes nil (infinite) timeout: down to wait, if none given' do
        expect(subject.instance_variable_get(:@state_changed)).to receive(:wait).with(anything, nil)
        subject.wait_for_state(:started)
      end

      it 'enforces precondition that states must be symbols' do
        expect do
          subject.wait_for_state(:started, 'stopped')
        end.to raise_exception(ArgumentError, /states must be symbols .*got "stopped"/)
      end
    end
  end

  context 'FSM with no start state' do
    class SpecFsmWithNoStartState
      include Listen::FSM

      state :started, to: :stopped

      state :failed, to: :stopped

      state :stopped

      def initialize
        initialize_fsm
      end
    end

    subject(:fsm) { SpecFsmWithNoStartState.new }

    it 'raises ArgumentError on new' do
      expect { subject }.to raise_exception(ArgumentError,
                                            /`start_state :<state>` must be declared before `new`/)
    end
  end

  context 'FSM with string state name' do
    subject(:fsm) do
      instance_exec do
        class SpecFsmWithStringState
          include Listen::FSM

          state 'started', to: 'stopped'

          state 'stopped'

          def initialize
            initialize_fsm
          end
        end
      end
    end

    it 'raises ArgumentError on new' do
      expect { subject }.to raise_exception(ArgumentError, /state name must be a Symbol/)
    end
  end
end
