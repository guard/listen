# frozen_string_literal: true

require 'listen/adapter/process_linux'

RSpec.describe Listen::Adapter::ProcessLinux do
  describe 'class' do
    subject { described_class }

    if linux?
      it { should be_usable }
    else
      it { should_not be_usable }
    end

    it '.forks? returns true' do
      expect(described_class.forks?).to be true
    end
  end
end
