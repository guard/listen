require 'spec_helper'

describe Listen::Adapter::TCP do

  let(:host) { '10.0.0.2' }
  let(:port) { 4000 }

  subject { described_class.new(listener) }
  let(:registry) { double(Celluloid::Registry) }
  let(:listener) { double(Listen::TCP::Listener, registry: registry, options: {}, host: host, port: port) }
  let(:socket)   { double(described_class::TCPSocket, close: true, recv: nil) }

  before do
    described_class::TCPSocket.stub(:new).and_return socket
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
      expect(described_class::TCPSocket).to receive(:new).with listener.host, listener.port
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
    let(:async) { double('TCP-adapter async', handle_data: true) }

    it 'handles data from socket' do
      socket.stub(:recv).and_return 'foo', 'bar', nil
      subject.stub(:async).and_return async

      expect(async).to receive(:handle_data).with 'foo'
      expect(async).to receive(:handle_data).with 'bar'

      subject.start
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

      Listen::TCP::Message.stub(:from_buffer).and_return message, nil
      expect(Listen::TCP::Message).to receive(:from_buffer).with 'foo'
      expect(subject.wrapped_object).to receive(:handle_message).with message

      subject.start
      subject.handle_data 'foo'
    end
  end

  describe '#handle_message' do
    it 'notifies listener of path changes' do
      message = Listen::TCP::Message.new(
        'modified' => ['/foo', '/bar'],
        'added'    => ['/baz'],
        'removed'  => []
      )

      expect(subject.wrapped_object).to receive(:_notify_change).with '/foo', change: :modified
      expect(subject.wrapped_object).to receive(:_notify_change).with '/bar', change: :modified
      expect(subject.wrapped_object).to receive(:_notify_change).with '/baz', change: :added

      subject.handle_message message
    end
  end

end
