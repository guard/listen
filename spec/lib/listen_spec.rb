require 'spec_helper'

describe Listen do
  describe '.to' do
    it 'initalizes listener' do
      expect(Listen::Listener).to receive(:new).with('/path')
      described_class.to('/path')
    end

    context 'when using :forward_to option' do
      it 'initializes TCP-listener in broadcast-mode' do
        expect(Listen::TCP::Listener).to receive(:new).
          with(4000, :broadcaster, '/path', {})
        described_class.to('/path', forward_to: 4000)
      end
    end

    it 'sets stopping at false' do
      allow(Listen::Listener).to receive(:new)
      Listen.to('/path')
      expect(Listen.stopping).to be_false
    end
  end

  describe '.stop' do
    it 'stops all listeners & Celluloid' do
      Listen.stop

      # TODO: running? returns internal_pool on 0.15.2
      # (remove after Celluloid dependency is bumped)
      buggy_method = if Celluloid.respond_to?(:internal_pool)
                       Celluloid.running? == Celluloid.internal_pool
                     else
                       false
                     end

      pool = buggy_method ? Celluloid.internal_pool : Celluloid
      expect(pool).to_not be_running
    end
  end

  describe '.on' do
    it 'initializes TCP-listener in recipient-mode' do
      expect(Listen::TCP::Listener).to receive(:new).
        with(4000, :recipient, '/path')
      described_class.on(4000, '/path')
    end
  end
end
