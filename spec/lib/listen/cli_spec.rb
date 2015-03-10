require 'listen/cli'

RSpec.describe Listen::CLI do
  let(:options) { {} }
  let(:forwarder) { instance_double(Listen::Forwarder) }

  before do
    allow(forwarder).to receive(:start)
  end

  describe 'relative option' do
    context 'without relative option' do
      let(:options) { %w[] }
      it 'is set to false' do
        expect(Listen::Forwarder).to receive(:new) do |options|
          expect(options[:relative]).to be(false)
          forwarder
        end
        described_class.start(options)
      end
    end

    context 'when -r' do
      let(:options) { %w[-r] }

      it 'is set to true' do
        expect(Listen::Forwarder).to receive(:new) do |options|
          expect(options[:relative]).to be(true)
          forwarder
        end
        described_class.start(options)
      end
    end

    context 'when --relative' do
      let(:options) { %w[--relative] }

      it 'supports -r option' do
        expect(Listen::Forwarder).to receive(:new) do |options|
          expect(options[:relative]).to be(true)
          forwarder
        end
        described_class.start(options)
      end

      it 'supports --relative option' do
        expect(Listen::Forwarder).to receive(:new) do |options|
          expect(options[:relative]).to be(true)
          forwarder
        end
        described_class.start(options)
      end
    end
  end
end

RSpec.describe Listen::Forwarder do
  let(:logger) { instance_double(Logger) }
  let(:listener) { instance_double(Listen::Listener) }

  before do
    allow(Logger).to receive(:new).and_return(logger)
    allow(logger).to receive(:level=)
    allow(logger).to receive(:formatter=)
    allow(logger).to receive(:info)

    allow(listener).to receive(:start)
    allow(listener).to receive(:listen?).and_return false
  end

  it 'passes relative option to Listen' do
    value = double('value')
    expect(Listen).to receive(:to).
      with(nil, hash_including(relative: value)).
      and_return(listener)

    described_class.new(relative: value).start
  end
end
