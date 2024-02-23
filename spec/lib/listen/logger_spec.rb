# frozen_string_literal: true

require 'listen/logger'

RSpec.describe 'logger.rb' do
  around do |spec|
    orig_logger = Listen.instance_variable_get(:@logger)

    spec.run

    Listen.logger = orig_logger
  end

  describe 'Listen.logger' do
    ENV_VARIABLE_NAME = 'LISTEN_GEM_DEBUGGING'

    let(:logger) { instance_double(::Logger, "logger") }

    around do |spec|
      orig_debugging_env_variable = ENV.fetch(ENV_VARIABLE_NAME, :not_set)

      spec.run

      if orig_debugging_env_variable == :not_set
        ENV.delete(ENV_VARIABLE_NAME)
      else
        ENV[ENV_VARIABLE_NAME] = orig_debugging_env_variable
      end
    end

    describe 'logger=' do
      it 'allows the logger to be set' do
        Listen.logger = logger
        expect(Listen.logger).to be(logger)
      end

      it 'allows nil to be set (implying default logger)' do
        Listen.logger = nil
        expect(Listen.logger).to be_kind_of(::Logger)
      end
    end

    describe 'logger' do
      before do
        Listen.instance_variable_set(:@logger, nil)
      end

      it 'returns default logger if none set' do
        expect(Listen.logger).to be_kind_of(::Logger)
      end

      ['debug', 'DEBUG', '2', 'level2', '2 '].each do |env_value|
        it "infers DEBUG level from #{ENV_VARIABLE_NAME}=#{env_value.inspect}" do
          ENV[ENV_VARIABLE_NAME] = env_value
          expect(Listen.logger.level).to eq(::Logger::DEBUG)
        end
      end

      ['info', 'INFO', 'true', ' true', 'TRUE', 'TRUE ', 'yes', 'YES', ' yesss!', '1', 'level1'].each do |env_value|
        it "infers INFO level from #{ENV_VARIABLE_NAME}=#{env_value.inspect}" do
          ENV[ENV_VARIABLE_NAME] = env_value
          expect(Listen.logger.level).to eq(::Logger::INFO)
        end
      end

      ['warn', 'WARN', ' warn', 'warning'].each do |env_value|
        it "infers WARN level from #{ENV_VARIABLE_NAME}=#{env_value.inspect}" do
          ENV[ENV_VARIABLE_NAME] = env_value
          expect(Listen.logger.level).to eq(::Logger::WARN)
        end
      end

      ['error', 'ERROR', 'OTHER'].each do |env_value|
        it "infers ERROR level from #{ENV_VARIABLE_NAME}=#{env_value.inspect}" do
          ENV[ENV_VARIABLE_NAME] = env_value
          expect(Listen.logger.level).to eq(::Logger::ERROR)
        end
      end

      ['fatal', 'FATAL', ' fatal'].each do |env_value|
        it "infers FATAL level from #{ENV_VARIABLE_NAME}=#{env_value.inspect}" do
          ENV[ENV_VARIABLE_NAME] = env_value
          expect(Listen.logger.level).to eq(::Logger::FATAL)
        end
      end
    end
  end

  describe 'Listen.adapter_warn_behavior' do
    subject { Listen.adapter_warn(message) }

    after do
      Listen.adapter_warn_behavior = :warn
    end
    let(:message) { "warning message" }

    it 'defaults to :warn' do
      expect(Listen.adapter_warn_behavior).to eq(:warn)

      expect(Listen).to receive(:warn).with(message)

      subject
    end

    it 'allows the adapter_warn_behavior to be set to :log' do
      Listen.adapter_warn_behavior = :log

      expect(Listen.logger).to receive(:warn).with(message)

      subject
    end

    [:silent, nil, false].each do |behavior|
      it "allows the adapter_warn_behavior to be set to #{behavior} to silence the warnings" do
        Listen.adapter_warn_behavior = behavior

        expect(Listen.logger).not_to receive(:warn)
        expect(Listen).not_to receive(:warn)

        subject
      end
    end

    context "when LISTEN_GEM_ADAPTER_WARN_BEHAVIOR is set to 'log'" do
      around do |spec|
        orig_debugging_env_variable = ENV.fetch('LISTEN_GEM_ADAPTER_WARN_BEHAVIOR', :not_set)

        ENV['LISTEN_GEM_ADAPTER_WARN_BEHAVIOR'] = 'log'

        spec.run

        if orig_debugging_env_variable == :not_set
          ENV.delete('LISTEN_GEM_ADAPTER_WARN_BEHAVIOR')
        else
          ENV['ENV_VARIABLE_NAME'] = orig_debugging_env_variable
        end
      end

      [:silent, nil, false, :warn].each do |behavior|
        it "respects the environment variable over #{behavior.inspect}" do
          Listen.adapter_warn_behavior = behavior

          expect(Listen.logger).to receive(:warn).with(message)

          subject
        end
      end

      it "respects the environment variable over a callable config" do
        Listen.adapter_warn_behavior = ->(_message) { :warn }

        expect(Listen.logger).to receive(:warn).with(message)

        subject
      end
    end

    context 'when adapter_warn_behavior is set to a callable object like a proc' do
      before do
        Listen.adapter_warn_behavior = ->(message) do
          case message
          when /USE warn/
            :warn
          when /USE log/
            :log
          when /USE silent/
            :silent
          when /USE false/
            false
          when /USE nil/
            nil
          else
            true
          end
        end
      end

      [true, :warn].each do |behavior|
        context "when the message matches a #{behavior.inspect} pattern" do
          let(:message) { "USE #{behavior.inspect}" }
          it 'respects :warn' do
            expect(Listen).to receive(:warn).with(message)

            subject
          end
        end
      end

      context 'when the message matches a :silent pattern' do
        let(:message) { "USE silent" }
        it 'respects :silent' do
          expect(Listen).not_to receive(:warn).with(message)
          expect(Listen).not_to receive(:warn)

          subject
        end
      end

      [false, nil].each do |behavior|
        context 'when the message matches a #{behavior} pattern' do
          let(:message) { "USE #{behavior.inspect}" }
          it 'respects :silent' do
            expect(Listen).not_to receive(:warn).with(message)
            expect(Listen).not_to receive(:warn)

            subject
          end
        end
      end
    end
  end
end
