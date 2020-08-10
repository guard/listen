# Code copied from https://github.com/celluloid/celluloid-fsm

require 'thread'

module Listen
  module FSM
    START_STATE = :default # Start state name unless one is explicitly set

    # Included hook to extend class methods
    def self.included(klass)
      klass.send :extend, ClassMethods
    end

    module ClassMethods
      # Obtain or set the start state
      # Passing a state name sets the start state
      def start_state(new_start_state = nil)
        if new_start_state
          @start_state = new_start_state.to_sym
        else
          defined?(@start_state) ? @start_state : START_STATE
        end
      end

      # Obtain the valid states for this FSM
      def states
        @states ||= {}
      end

      # Declare an FSM state and optionally provide a callback block to fire on state entry
      # Options:
      # * start: make this the start state
      # * to: a state or array of states this state can transition to
      def state(*args, start: nil, to: nil, &block)
        args.each do |name|
          name = name.to_sym
          start_state(name) if start
          states[name] = State.new(name, to, &block)
        end
      end
    end

    # Be kind and call super if you must redefine initialize
    def initialize
      @state = self.class.start_state
      @mutex = ::Mutex.new
      @state_changed = ::ConditionVariable.new
    end

    # Current state of the FSM
    attr_reader :state

    def transition(state_name)
      if (new_state = validate_and_sanitize_new_state(state_name))
        transition_with_callbacks!(new_state)
      end
    end

    # Low-level, immediate state transition with no checks or callbacks.
    def transition!(new_state)
      @mutex.synchronize do
        yield if block_given?
        @state = new_state
        @state_changed.signal
      end
    end

    # checks for one of the given states
    # if not already, waits for a state change (up to timeout seconds--`nil` means infinite)
    # returns truthy iff the transition to one of the desired state has occurred
    def wait_for_state(*wait_for_states, timeout: nil)
      @mutex.synchronize do
        if !wait_for_states.include?(@state)
          @state_changed.wait(@mutex, timeout)
        end
        wait_for_states.include?(@state)
      end
    end

    protected

    def validate_and_sanitize_new_state(state_name)
      state_name = state_name.to_sym

      return if current_state_name == state_name

      if current_state && !current_state.valid_transition?(state_name)
        valid = current_state.transitions.map(&:to_s).join(', ')
        msg = "#{self.class} can't change state from '#{@state}' to '#{state_name}', only to: #{valid}"
        raise ArgumentError, msg
      end

      unless (new_state = states[state_name])
        state_name == start_state or raise ArgumentError, "invalid state for #{self.class}: #{state_name}"
      end

      new_state
    end

    def transition_with_callbacks!(state_name)
      transition! state_name.name
      state_name.call(self)
    end

    def states
      self.class.states
    end

    def start_state
      self.class.start_state
    end

    def current_state
      states[@state]
    end

    def current_state_name
      current_state && current_state.name || ''
    end

    class State
      attr_reader :name, :transitions

      def initialize(name, transitions = nil, &block)
        @name = name
        @block = block
        @transitions = if transitions
                         Array(transitions).map(&:to_sym)
                       end
      end

      def call(obj)
        obj.instance_eval(&@block) if @block
      end

      def valid_transition?(new_state)
        # All transitions are allowed if none are expressly declared
        !@transitions || @transitions.include?(new_state.to_sym)
      end
    end
  end
end
