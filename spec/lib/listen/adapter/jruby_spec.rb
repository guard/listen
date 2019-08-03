RSpec.describe Listen::Adapter::Jruby do
  describe 'class' do
    subject { described_class }

    if jruby?
      it { should be_usable }
    else
      it { should_not be_usable }
    end
  end
end
