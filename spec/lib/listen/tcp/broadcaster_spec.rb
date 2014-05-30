require 'spec_helper'

require 'listen/tcp/broadcaster'

describe Listen::TCP::Broadcaster do

  let(:host) { '10.0.0.2' }
  let(:port) { 4000 }

  subject { described_class.new(host, port) }

  let(:server) do
    instance_double(described_class::TCPServer, close: true, accept: nil)
  end

  let(:socket) do
    instance_double(described_class::TCPSocket, close: true, write: true)
  end

  let(:socket2) do
    instance_double(described_class::TCPSocket, close: true, write: true)
  end

  let(:payload) { Listen::TCP::Message.new.payload }

  before do
    expect(described_class::TCPServer).to receive(:new).
      with(host, port).and_return server
    allow(server).to receive(:accept).and_raise('stub called')
  end

  after do
    subject.terminate
  end

  describe '#start' do
    it 'invokes run loop asynchronously' do
      expect_any_instance_of(described_class).to receive(:run)
      subject.start
    end
  end

  describe '#finalize' do
    before { allow(server).to receive(:accept).and_return nil }

    it 'closes server' do
      expect(server).to receive(:close)
      subject.finalize
    end
  end

  describe '#broadcast' do
    context 'with active socket' do
      before { allow(server).to receive(:accept).and_return socket, nil }

      it 'should broadcast payload' do
        expect(socket).to receive(:write).with(payload)
        subject.run
        subject.broadcast payload
      end

      it 'should keep socket' do
        expect(socket).to receive(:write).twice.with(payload)
        subject.run
        2.times { subject.broadcast payload }
      end

      context 'with IOError' do
        it 'should remove socket from list' do
          allow(socket).to receive(:write).once.and_raise IOError
          subject.run
          2.times { subject.broadcast payload }
        end
      end

      context 'when reset by peer' do
        it 'should remove socket from list' do
          allow(socket).to receive(:write).once.and_raise Errno::ECONNRESET
          subject.run
          2.times { subject.broadcast payload }
        end
      end

      context 'when broken pipe' do
        it 'should remove socket from list' do
          allow(socket).to receive(:write).once.and_raise Errno::EPIPE
          subject.run
          2.times { subject.broadcast payload }
        end
      end

      context 'with another active socket' do
        before do
          allow(server).to receive(:accept).and_return socket, socket2, nil
        end

        it 'should broadcast payload to both' do
          expect(socket).to receive(:write).with(payload)
          expect(socket2).to receive(:write).with(payload)
          subject.run
          subject.broadcast payload
        end

        context 'with a failure in first socket' do
          before do
            allow(socket).to receive(:write).once.and_raise Errno::EPIPE
          end

          it 'should still broadcast to remaining socket' do
            expect(socket2).to receive(:write).with(payload)
            subject.run
            subject.broadcast payload
          end

          it 'should broadcast to only remaining socket' do
            expect(socket2).to receive(:write).twice.with(payload)
            subject.run
            2.times { subject.broadcast payload }
          end
        end
      end
    end
  end
end
