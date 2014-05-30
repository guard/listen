require 'spec_helper'

describe Listen::Listener do

  let(:port) { 4000 }
  let(:broadcast_options) { { forward_to: port } }
  let(:paths) { Pathname.new(Dir.pwd) }

  around { |example| fixtures { example.run } }

  modes = if !windows? || Celluloid::VERSION > '0.15.2'
            [:recipient, :broadcaster]
          else
            [:broadcaster]
          end

  modes.each do |mode|
    context "when #{mode}" do
      if mode == :broadcaster
        subject { setup_listener(broadcast_options, :track_changes) }
        before { subject.listener.start }
        after { subject.listener.stop }
      else
        subject { setup_recipient(port, :track_changes) }
        let(:broadcaster) { setup_listener(broadcast_options) }

        before do
          broadcaster.listener.start
          # Travis on OSX is too slow
          subject.lag = 1.2
          subject.listener.start
        end
        after do
          broadcaster.listener.stop
          subject.listener.stop
        end
      end

      it { should process_addition_of('file.rb') }

      context 'when paused' do
        before { subject.listener.pause }

        context 'with no queued changes' do
          it { should_not process_addition_of('file.rb') }

          context 'when unpaused' do
            before { subject.listener.unpause }
            it { should process_addition_of('file.rb') }
          end
        end

        context 'with queued addition' do
          before { change_fs(:added, 'file.rb') }
          it { should_not process_modification_of('file.rb') }

          context 'when unpaused' do
            before { subject.listener.unpause }
            it { should process_queued_addition_of('file.rb') }
            it { should process_modification_of('file.rb') }
          end
        end

        context 'with queued modification' do
          before do
            change_fs(:added, 'file.rb')
            change_fs(:modified, 'file.rb')
          end

          it { should_not process_queued_addition_of('file.rb') }
          it { should_not process_queued_modification_of('file.rb') }

          context 'when unpaused' do
            before { subject.listener.unpause }
            it { should process_queued_addition_of('file.rb') }

            # NOTE: when adapter is 'local_fs?', the change optimizer
            # (_squash_changes) reduces the "add+mod" into a single "add"
            if mode == :broadcaster
              # "optimizing" on local fs (broadcaster) will remove
              # :modified from queue
              it { should_not process_queued_modification_of('file.rb') }
            else
              # optimization skipped, because it's TCP, so we'll have both
              # :modified and :added events for same file
              it { should process_queued_modification_of('file.rb') }
            end

            it { should process_modification_of('file.rb') }
          end
        end
      end

      context 'when stopped' do
        before { subject.listener.stop }

        context 'with no queued changes' do
          it { should_not process_addition_of('file.rb') }

          context 'when started' do
            before { subject.listener.start }
            it { should process_addition_of('file.rb') }
          end
        end

        context 'with queued addition' do
          before { change_fs(:added, 'file.rb') }
          it { should_not process_modification_of('file.rb') }

          context 'when started' do
            before { subject.listener.start }
            it { should_not process_queued_addition_of('file.rb') }
            it { should process_modification_of('file.rb') }
          end
        end

        context 'with queued modification' do
          before do
            change_fs(:added, 'file.rb')
            change_fs(:modified, 'file.rb')
          end

          it { should_not process_queued_addition_of('file.rb') }
          it { should_not process_queued_modification_of('file.rb') }

          context 'when started' do
            before { subject.listener.start }
            it { should_not process_queued_addition_of('file.rb') }
            it { should_not process_queued_modification_of('file.rb') }
            it { should process_modification_of('file.rb') }
          end
        end
      end
    end
  end
end
