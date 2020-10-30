# frozen_string_literal: true

require 'listen/logger'

RSpec.describe 'Listen.logger' do
  ENV_VARIABLE_NAME = 'LISTEN_GEM_DEBUGGING'

  let(:logger) { instance_double(::Logger, "logger") }

  around do |spec|
    orig_logger = Listen.instance_variable_get(:@logger)

    spec.run

    Listen.logger = orig_logger
  end

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
