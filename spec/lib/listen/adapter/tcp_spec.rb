require 'spec_helper'

describe Listen::Adapter::TCP do

  let(:host) { '10.0.0.2' }
  let(:port) { 4000 }

  let(:options) { { host: host, port: port } }

  subject { described_class.new(options.merge(mq: listener)) }
  let(:registry) { instance_double(Celluloid::Registry) }

  let(:listener) do
    instance_double(
      Listen::Listener,
      registry: registry,
      options: {},
      host: host,
      port: port)
  end

  let(:socket) do
    instance_double(described_class::TCPSocket, close: true, recv: nil)
  end

  before do
    allow(described_class::TCPSocket).to receive(:new).and_return socket
  end

  after do
    subject.terminate
  end

  describe '.usable?' do
    it 'always returns true' do
      expect(described_class).to be_usable
    end
  end

  describe '#start' do
    it 'initializes and exposes a socket with listener host and port' do
      expect(described_class::TCPSocket).
        to receive(:new).
        with listener.host, listener.port

      subject.start
      expect(subject.socket).to be socket
    end

    it 'initializes and exposes a string buffer' do
      subject.start
      expect(subject.buffer).to eq ''
    end

    it 'invokes run loop' do
      expect(subject.wrapped_object).to receive(:run)
      subject.start
    end
  end

  describe '#finalize' do
    it 'clears buffer' do
      subject.start
      subject.finalize
      expect(subject.buffer).to be_nil
    end

    it 'closes socket' do
      subject.start
      expect(subject.socket).to receive(:close)
      subject.finalize
      expect(subject.socket).to be_nil
    end
  end

  describe '#run' do
    it 'handles data from socket' do
      allow(socket).to receive(:recv).and_return 'foo', 'bar', nil

      expect_any_instance_of(described_class).
        to receive(:handle_data).with('foo')

      expect_any_instance_of(described_class).
        to receive(:handle_data).with('bar')

      subject.start

      # quick workaround because run is called asynchronously
      sleep 0.5
    end
  end

  describe '#handle_data' do
    it 'buffers data' do
      subject.start
      subject.handle_data 'foo'
      subject.handle_data 'bar'
      expect(subject.buffer).to eq 'foobar'
    end

    it 'handles messages accordingly' do
      message = Listen::TCP::Message.new

      allow(Listen::TCP::Message).to receive(:from_buffer).
        and_return message, nil

      expect(Listen::TCP::Message).to receive(:from_buffer).with 'foo'
      expect(subject.wrapped_object).to receive(:handle_message).with message

      subject.start
      subject.handle_data 'foo'
    end
  end

  describe '#handle_message' do
    let(:dir) { Pathname.pwd }
    it 'notifies listener of path changes' do
      message = Listen::TCP::Message.new('file', 'modified', dir, 'foo', {})

      expect(subject.wrapped_object).
        to receive(:_queue_change).with :file, dir, 'foo', change: :modified

      subject.handle_message message
    end
  end

  specify { expect(described_class).to_not be_local_fs }

end
