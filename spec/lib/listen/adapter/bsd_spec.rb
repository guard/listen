# frozen_string_literal: true

RSpec.describe Listen::Adapter::BSD do
  describe 'class' do
    subject { described_class }

    if bsd?
      it { should be_usable }
    else
      it { should_not be_usable }
    end
  end
end
