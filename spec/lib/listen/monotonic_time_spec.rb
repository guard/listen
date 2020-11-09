# frozen_string_literal: true

require 'listen/monotonic_time'

RSpec.describe Listen::MonotonicTime do
  after(:all) do
    # load once more with constants unstubbed/unhidden
    load './lib/listen/monotonic_time.rb'
  end

  context 'module methods' do
    describe '.now' do
      subject { described_class.now }
      let(:tick_count) { 0.123 }

      context 'when CLOCK_MONOTONIC defined' do
        before do
          stub_const('Process::CLOCK_MONOTONIC', 10)
          load './lib/listen/monotonic_time.rb'
        end

        it 'returns the CLOCK_MONOTONIC tick count' do
          expect(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(tick_count)
          expect(subject).to eq(tick_count)
        end
      end

      context 'when CLOCK_MONOTONIC not defined but CLOCK_MONOTONIC_RAW defined' do
        before do
          hide_const('Process::CLOCK_MONOTONIC')
          stub_const('Process::CLOCK_MONOTONIC_RAW', 11)
          load './lib/listen/monotonic_time.rb'
        end

        it 'returns the floating point Time.now' do
          expect(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC_RAW).and_return(tick_count)
          expect(subject).to eq(tick_count)
        end
      end

      context 'when neither CLOCK_MONOTONIC nor CLOCK_MONOTONIC_RAW defined' do
        let(:now) { instance_double(Time, "time") }

        before do
          hide_const('Process::CLOCK_MONOTONIC')
          hide_const('Process::CLOCK_MONOTONIC_RAW')
          load './lib/listen/monotonic_time.rb'
        end

        it 'returns the floating point Time.now' do
          expect(Time).to receive(:now).and_return(now)
          expect(now).to receive(:to_f).and_return(tick_count)
          expect(subject).to eq(tick_count)
        end
      end
    end
  end
end
