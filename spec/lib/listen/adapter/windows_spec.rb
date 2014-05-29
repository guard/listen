require 'spec_helper'

describe Listen::Adapter::Windows do
  describe 'class' do
    subject { described_class }
    it { should be_local_fs }

    if windows?
      it { should be_usable }
    else
      it { should_not be_usable }
    end
  end
end
