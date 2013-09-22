require 'spec_helper'

describe Listen::TCP::Broadcaster do

  let(:host) { '127.0.0.1' }
  let(:port) { 4000 }

  subject {
    described_class.new host, port
  }

  after do
    subject.finalize if subject.alive?
  end

  describe '#initialize' do
    its(:server)  { should be_a Celluloid::IO::TCPServer }
    its(:sockets) { should be_an Array }
  end

  describe '#finalize' do
    it 'closes server' do
      expect(subject.server).to receive(:close).and_call_original
    end

    it 'clears sockets' do
      expect(subject.sockets).to receive(:clear)
    end
  end

  # TODO: Spec all the things

end
