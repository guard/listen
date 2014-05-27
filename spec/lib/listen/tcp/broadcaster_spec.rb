require 'spec_helper'

require 'listen/tcp/broadcaster'

describe Listen::TCP::Broadcaster do

  let(:host) { '10.0.0.2' }
  let(:port) { 4000 }

  subject { described_class.new(host, port) }
  let(:server) do
    instance_double(described_class::TCPServer, close: true, accept: nil)
  end

  let(:socket)  { instance_double(described_class::TCPSocket, write: true) }
  let(:payload) { Listen::TCP::Message.new.payload }

  before do
    expect(described_class::TCPServer).to receive(:new).
      with(host, port).and_return server
  end

  after do
    subject.terminate
  end

  describe '#initialize' do
    it 'initializes and exposes a server' do
      expect(subject.server).to be server
    end

    it 'initializes and exposes a list of sockets' do
      expect(subject.sockets).to eq []
    end
  end

  describe '#start' do
    it 'invokes run loop asynchronously' do
      expect_any_instance_of(described_class).to receive(:run)
      subject.start
    end
  end

  describe '#finalize' do
    it 'clears sockets' do
      expect(subject.sockets).to receive(:clear)
      subject.finalize
    end

    it 'closes server' do
      expect(subject.server).to receive(:close)
      subject.finalize
      expect(subject.server).to be_nil
    end
  end

  describe '#broadcast' do
    it 'unicasts to connected sockets' do
      subject.handle_connection socket
      expect(subject.wrapped_object).to receive(:unicast).with socket, payload
      subject.broadcast payload
    end
  end

  describe '#unicast' do
    before do
      subject.handle_connection socket
    end

    context 'when succesful' do
      it 'returns true and leaves socket untouched' do
        expect(subject.unicast(socket, payload)).to be_truthy
        expect(subject.sockets).to include socket
      end
    end

    context 'on IO errors' do
      it 'returns false and removes socket from list' do
        allow(socket).to receive(:write).and_raise IOError
        expect(subject.unicast(socket, payload)).to be_falsey
        expect(subject.sockets).not_to include socket
      end
    end

    context 'on connection reset by peer' do
      it 'returns false and removes socket from list' do
        allow(socket).to receive(:write).and_raise Errno::ECONNRESET
        expect(subject.unicast(socket, payload)).to be_falsey
        expect(subject.sockets).not_to include socket
      end
    end

    context 'on broken pipe' do
      it 'returns false and removes socket from list' do
        allow(socket).to receive(:write).and_raise Errno::EPIPE
        expect(subject.unicast(socket, payload)).to be_falsey
        expect(subject.sockets).not_to include socket
      end
    end
  end

  describe '#run' do
    it 'handles incoming connections' do
      allow(server).to receive(:accept).and_return socket, nil
      expect(subject.wrapped_object).to receive(:handle_connection).with socket
      subject.run
    end
  end

  describe '#handle_connection' do
    it 'adds socket to list' do
      subject.handle_connection socket
      expect(subject.sockets).to include socket
    end
  end

end
