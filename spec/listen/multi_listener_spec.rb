require 'spec_helper'

describe Listen::MultiListener do

  describe '#initialize' do
    it 'forward directly to its superclass' do
      Listen::Listener.should_receive(:new).with('foo', 'bar', { foo: :bar })
      described_class.new('foo', 'bar', { foo: :bar })
    end
  end

end
