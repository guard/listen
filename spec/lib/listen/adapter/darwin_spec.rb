require 'spec_helper'

require 'listen/adapter/darwin'

include Listen

describe Adapter::Darwin do
  describe 'class' do
    subject { described_class }
    it { should be_local_fs }

    if darwin?
      it { should be_usable }
    else
      it { should_not be_usable }
    end
  end

  let(:options) { {} }
  let(:mq) { instance_double(Listener, options: options) }

  describe '#_latency' do
    subject do
      adapter = described_class.new(options.merge(mq: mq, directories: []))
      adapter.options.latency
    end

    context 'with no overriding option' do
      it { should eq 0.1 }
    end

    context 'with custom latency overriding' do
      let(:options) { { latency: 1234 } }
      it { should eq 1234 }
    end
  end
end
