require 'spec_helper'

describe Listen::Adapter::Darwin do
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
  let(:listener) { instance_double(Listen::Listener, options: options) }

  describe '#_latency' do
    subject { described_class.new(listener).send(:_latency) }

    context 'with no overriding option' do
      it { should eq described_class.const_get('DEFAULT_LATENCY') }
    end

    context 'with custom latency overriding' do
      let(:options) { { latency: 1234 } }
      it { should eq 1234 }
    end
  end
end
