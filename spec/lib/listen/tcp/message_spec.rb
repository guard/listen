# encoding: utf-8

require 'spec_helper'

describe Listen::TCP::Message do

  let(:object)  { [1, 2, { 'foo' => 'bar' }] }
  let(:body)    { '[1,2,{"foo":"bar"}]' }
  let(:size)    { 19 }
  let(:payload) { "\x00\x00\x00\x13[1,2,{\"foo\":\"bar\"}]" }

  describe '#initialize' do
    it 'initializes with an object' do
      message = described_class.new(1, 2, 3)
      expect(message.object).to eq [1, 2, 3]
    end
  end

  describe '#object=' do
    subject do
      described_class.new(object).tap do |message|
        message.object = object
      end
    end

    describe '#object' do
      subject { super().object }
      it  { is_expected.to be object }
    end

    describe '#body' do
      subject { super().body }
      it { is_expected.to eq body }
    end

    describe '#size' do
      subject { super().size }
      it { is_expected.to eq size }
    end

    describe '#payload' do
      subject { super().payload }
      it { is_expected.to eq payload }
    end
  end

  describe '#payload=' do
    subject do
      described_class.new(object).tap do |message|
        message.payload = payload
      end
    end

    describe '#object' do
      subject { super().object }
      it { is_expected.to eq object }
    end

    describe '#body' do
      subject { super().body }
      it { is_expected.to eq body }
    end

    describe '#size' do
      subject { super().size }
      it { is_expected.to eq size }
    end

    describe '#payload' do
      subject { super().payload }
      it { is_expected.to be payload }
    end
  end

  describe '.from_buffer' do

    context 'when buffer is empty' do
      it 'returns nil and leaves buffer intact' do
        buffer = ''
        message = described_class.from_buffer buffer
        expect(message).to be_nil
        expect(buffer).to eq ''
      end
    end

    context 'when buffer has data' do

      context 'with a partial packet' do
        it 'returns nil and leaves remaining data intact' do
          buffer = payload[0..4]
          message = described_class.from_buffer buffer
          expect(message).to be_nil
          expect(buffer).to eq payload[0..4]
        end
      end

      context 'with a full packet' do
        it 'extracts message from buffer and depletes buffer' do
          buffer = payload.dup
          message = described_class.from_buffer buffer
          expect(message).to be_a described_class
          expect(message.object).to eq object
          expect(buffer).to eq ''
        end
      end

      context 'with a full and a partial packet' do
        it 'extracts message from buffer and leaves remaining data intact' do
          buffer = payload + payload[0..10]
          message = described_class.from_buffer buffer
          expect(message).to be_a described_class
          expect(message.object).to eq object
          expect(buffer).to eq payload[0..10]
        end
      end

      context 'with two full packets' do
        it 'extracts both messages from buffer and depletes buffer' do
          buffer = payload + payload

          message1 = described_class.from_buffer buffer
          expect(message1).to be_a described_class
          expect(message1.object).to eq object

          message2 = described_class.from_buffer buffer
          expect(message2).to be_a described_class
          expect(message2.object).to eq object

          expect(message1).not_to be message2
          expect(buffer).to eq ''
        end
      end

    end

  end

end
