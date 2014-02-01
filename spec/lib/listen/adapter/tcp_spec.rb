require 'spec_helper'

describe Listen::Adapter::TCP do

  describe '.usable?' do
    it 'always returns true' do
      expect(described_class).to be_usable
    end
  end

  # TODO: Spec all the things

end
