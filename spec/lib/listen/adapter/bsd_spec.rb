require 'spec_helper'

describe Listen::Adapter::BSD do
  describe 'class' do
    subject { described_class }
    it { should be_local_fs }

    if bsd?
      it { should be_usable }
    else
      it { should_not be_usable }
    end
  end
end
