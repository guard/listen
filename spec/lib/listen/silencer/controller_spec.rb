# frozen_string_literal: true

require 'listen/silencer/controller'

RSpec.describe Listen::Silencer::Controller do
  let(:silencer) { instance_double(Listen::Silencer) }

  describe 'append_ignores' do
    context 'with no previous :ignore rules' do
      subject do
        described_class.new(silencer, {})
      end

      before do
        allow(silencer).to receive(:configure).with({})
      end

      context 'when providing a nil' do
        it 'sets the given :ignore rules as empty array' do
          subject
          allow(silencer).to receive(:configure).with(ignore: [])
          subject.append_ignores(nil)
        end
      end

      context 'when providing a single regexp as argument' do
        it 'sets the given :ignore rules as array' do
          subject
          allow(silencer).to receive(:configure).with({ ignore: [/foo/] })
          subject.append_ignores(/foo/)
        end
      end

      context 'when providing multiple arguments' do
        it 'sets the given :ignore rules as a flat array' do
          subject
          allow(silencer).to receive(:configure).with({ ignore: [/foo/, /bar/] })
          subject.append_ignores(/foo/, /bar/)
        end
      end

      context 'when providing as array' do
        it 'sets the given :ignore rules' do
          subject
          allow(silencer).to receive(:configure).with({ ignore: [/foo/, /bar/] })
          subject.append_ignores([/foo/, /bar/])
        end
      end
    end

    context 'with previous :ignore rules' do
      subject do
        described_class.new(silencer, { ignore: [/foo/, /bar/] })
      end

      before do
        allow(silencer).to receive(:configure).with({ ignore: [/foo/, /bar/] })
      end

      context 'when providing a nil' do
        # TODO: should this invocation maybe reset the rules?
        it 'reconfigures with existing :ignore rules' do
          subject
          allow(silencer).to receive(:configure).with({ ignore: [/foo/, /bar/] })
          subject.append_ignores(nil)
        end
      end

      context 'when providing a single regexp as argument' do
        it 'appends the given :ignore rules as array' do
          subject
          expected = { ignore: [/foo/, /bar/, /baz/] }
          allow(silencer).to receive(:configure).with(expected)
          subject.append_ignores(/baz/)
        end
      end

      context 'when providing multiple arguments' do
        it 'appends the given :ignore rules as a flat array' do
          subject
          expected = { ignore: [/foo/, /bar/, /baz/, /bak/] }
          allow(silencer).to receive(:configure).with(expected)
          subject.append_ignores(/baz/, /bak/)
        end
      end

      context 'when providing as array' do
        it 'appends the given :ignore rules' do
          subject
          expected = { ignore: [/foo/, /bar/, /baz/, /bak/] }
          allow(silencer).to receive(:configure).with(expected)
          subject.append_ignores([/baz/, /bak/])
        end
      end
    end
  end
end
