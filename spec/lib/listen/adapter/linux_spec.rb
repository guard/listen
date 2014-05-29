require 'spec_helper'

describe Listen::Adapter::Linux do
  describe 'class' do
    subject { described_class }
    it { should be_local_fs }

    if linux?
      it { should be_usable }
    else
      it { should_not be_usable }
    end
  end

  if linux?
    let(:listener) { instance_double(Listen::Listener) }
    let(:adapter) { described_class.new(listener) }

    describe '#initialize' do
      before do
        allow(listener).to receive(:directories) { [] }
      end
      it 'requires rb-inotify gem' do
        adapter.send(:_configure)
        expect(defined?(INotify)).to be
      end
    end

    # workaround: Celluloid ignores SystemExit exception messages
    describe 'inotify limit message' do
      let!(:adapter) { described_class.new(listener) }

      before do
        require 'rb-inotify'
        allow(listener).to receive(:directories) { ['foo/dir'] }
        fake_worker = double(:fake_worker)
        allow(fake_worker).to receive(:watch).and_raise(Errno::ENOSPC)

        fake_notifier = double(:fake_notifier, new: fake_worker)
        stub_const('INotify::Notifier', fake_notifier)
      end

      it 'should be shown before calling abort' do
        expected_message = described_class.const_get('INOTIFY_LIMIT_MESSAGE')
        expect(STDERR).to receive(:puts).with(expected_message)

        # Expect RuntimeError here, for the sake of unit testing (actual
        # handling depends on Celluloid supervisor setup, which is beyond the
        # scope of adapter tests)
        expect { adapter.start }.to raise_error RuntimeError, expected_message
      end
    end

    describe '_callback' do
      before do
        allow(listener).to receive(:directories) { [] }
      end

      let(:expect_change) do
        lambda do |change|
          allow_any_instance_of(Listen::Adapter::Base).
            to receive(:_notify_change).
            with(
              :file,
              Pathname.new('path/foo.txt'),
              change: change,
              cookie: 123)
        end
      end

      let(:event_callback) do
        lambda do |flags|
          callback = adapter.send(:_callback)
          callback.call double(
            :inotify_event,
            name: 'foo.txt',
            watcher: double(:watcher, path: 'path'),
            flags: flags,
            cookie: 123)
        end
      end

      # TODO: get fsevent adapter working like INotify
      unless /1|true/ =~ ENV['LISTEN_GEM_SIMULATE_FSEVENT']
        it 'recognizes close_write as modify' do
          expect_change.call(:modified)
          event_callback.call([:close_write])
        end

        it 'recognizes moved_to as moved_to' do
          expect_change.call(:moved_to)
          event_callback.call([:moved_to])
        end

        it 'recognizes moved_from as moved_from' do
          expect_change.call(:moved_from)
          event_callback.call([:moved_from])
        end
      end
    end
  end
end
