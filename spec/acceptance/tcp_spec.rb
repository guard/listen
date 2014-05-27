require 'spec_helper'

describe Listen::Listener do

  let(:port) { 4000 }
  let(:broadcast_options) { { forward_to: port } }
  let(:paths) { Pathname.new(Dir.pwd) }

  around { |example| fixtures { example.run } }
  before { broadcaster.listener.start }

  let(:report_nothing) { Proc.new {} }

  context 'when broadcaster' do
    let(:broadcaster) { setup_listener(broadcast_options) }
    let(:recipient) { setup_recipient(port, report_nothing) }

    it 'still handles local changes' do
      expect(broadcaster).to detect_addition_of('file.rb')
    end

    it 'may be paused and unpaused' do
      broadcaster.listener.pause
      expect(recipient).to_not detect_addition_of('file.rb')
      expect(recipient).to_not detect_modification_of('file.rb')

      broadcaster.listener.unpause
      expect(broadcaster).to detect_modification_of('file.rb')
    end

    it 'may be stopped and restarted' do
      broadcaster.listener.stop
      expect(recipient).to_not detect_addition_of('file.rb')
      expect(recipient).to_not detect_modification_of('file.rb')

      broadcaster.listener.start
      expect(broadcaster).to detect_modification_of('file.rb')
    end
  end

  # (Broken because it's looking for /etc/resolv.conf)
  unless windows? && Celluloid::VERSION <= '0.15.2'

    context 'when recipient' do
      let(:broadcaster) { setup_listener(broadcast_options, report_nothing) }
      let(:recipient) { setup_recipient(port) }

      before do
        broadcaster.lag = 2
        recipient.listener.start
      end

      it 'receives changes over TCP' do
        expect(recipient).to detect_addition_of('file.rb')
      end

      it 'may be paused and unpaused' do
        recipient.listener.pause
        expect(recipient).to_not detect_addition_of('file.rb')
        expect(recipient).to_not detect_modification_of('file.rb')

        recipient.listener.unpause
        expect(recipient).to detect_modification_of('file.rb')
      end

      it 'may be stopped and restarted' do
        recipient.listener.stop
        expect(recipient).to_not detect_addition_of('file.rb')
        expect(recipient).to_not detect_modification_of('file.rb')

        recipient.listener.start
        expect(recipient).to detect_modification_of('file.rb')
      end
    end
  end

end
