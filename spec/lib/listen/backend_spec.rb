# frozen_string_literal: true

require 'listen/backend'

RSpec.describe Listen::Backend do
  let(:dir1) { instance_double(Pathname, 'dir1', to_s: '/foo/dir1') }

  let(:silencer) { instance_double(Listen::Silencer) }
  let(:queue) { instance_double(Queue) }

  let(:select_options) do
    { force_polling: false, polling_fallback_message: 'foo' }
  end

  let(:adapter_options) { { latency: 1234 } }
  let(:options) { select_options.merge(adapter_options) }

  let(:adapter_config_class) { class_double('Listen::Adapter::Config') }
  let(:adapter_config) { instance_double('Listen::Adapter::Config') }

  let(:config) { instance_double(Listen::Listener::Config) }

  subject { described_class.new([dir1], queue, silencer, config) }

  # Use Polling since it has a valid :latency option
  let(:adapter_defaults) { { latency: 5.4321 } }
  let(:adapter_class) { Listen::Adapter::Polling }
  let(:adapter) { instance_double('Listen::Adapter::Polling') }

  let(:config_min_delay_between_events) { 0.1234 }

  before do
    stub_const('Listen::Adapter::Config', adapter_config_class)

    allow(adapter_config_class).to receive(:new).
      with([dir1], queue, silencer, adapter_options).
      and_return(adapter_config)

    allow(Listen::Adapter).to receive(:select).
      with(select_options).and_return(adapter_class)

    allow(adapter_class).to receive(:new).
      with(adapter_config).and_return(adapter)

    allow(Listen::Adapter::Polling).to receive(:new).with(adapter_config).
      and_return(adapter)

    allow(config).to receive(:adapter_select_options).
      and_return(select_options)

    allow(config).to receive(:adapter_instance_options).
      and_return(adapter_options)

    allow(config).to receive(:min_delay_between_events).
      and_return(config_min_delay_between_events)
  end

  describe '#initialize' do
    context 'with config' do
      it 'sets up an adapter class' do
        expect(adapter_class).to receive(:new).
          with(adapter_config).and_return(adapter)

        subject
      end
    end
  end

  describe '#start' do
    it 'starts the adapter' do
      expect(adapter).to receive(:start)
      subject.start
    end
  end

  describe '#stop' do
    it 'stops the adapter' do
      expect(adapter).to receive(:stop)
      subject.stop
    end
  end
end
