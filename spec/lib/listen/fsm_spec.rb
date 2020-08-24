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
