require 'spec_helper'

describe Listen::MultiListener do

  describe '#initialize' do
    let(:options) do
      {
        ignore: /\.ssh/, filter: [/.*\.rb/, /.*\.md/],
        latency: 0.5, force_polling: true
      }
    end

    it 'forward directly to its superclass' do
      Listen::Listener.should_receive(:new).with('foo', 'bar', options)
      described_class.new('foo', 'bar', options)
    end
  end

end
