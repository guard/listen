# frozen_string_literal: true

require 'listen/listener/config'
RSpec.describe Listen::Listener::Config do
  describe 'options' do
    context 'custom options' do
      subject do
        described_class.new(
          latency: 1.234,
          wait_for_delay: 0.85,
          force_polling: true,
          relative: true)
      end

      it 'extracts adapter options' do
        klass = Class.new do
          DEFAULTS = { latency: 5.4321 }.freeze
        end
        expected = { latency: 1.234 }
        expect(subject.adapter_instance_options(klass)).to eq(expected)
      end

      it 'extract adapter selecting options' do
        expected = { force_polling: true, polling_fallback_message: nil }
        expect(subject.adapter_select_options).to eq(expected)
      end
    end
  end
end
