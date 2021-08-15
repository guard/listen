# frozen_string_literal: true

RSpec.describe Listen::Adapter::Linux do
  describe 'class methods' do
    subject { described_class }

    if linux?
      it { should be_usable }
    else
      it { should_not be_usable }
    end
  end

  if linux?
    describe 'instance methods' do
      before(:all) do
        require 'rb-inotify'
      end

      let(:dir1) { Pathname.new("/foo/dir1") }

      let(:queue) { instance_double(Queue, "queue", close: nil) }
      let(:config) { instance_double(Listen::Adapter::Config, "config", queue: queue) }
      let(:silencer) { instance_double(Listen::Silencer, "silencer") }
      let(:snapshot) { instance_double(Listen::Change, "snapshot") }
      let(:record) { instance_double(Listen::Record, "record") }

      # TODO: fix other adapters too!
      subject { described_class.new(config) }

      after do
        subject.stop
      end

      describe 'watch events' do
        let(:directories) { [Pathname.pwd] }
        let(:adapter_options) { {} }
        let(:default_events) { [:recursive, :attrib, :create, :modify, :delete, :move, :close_write] }
        let(:fake_worker) { double(:fake_worker_for_watch_events) }
        let(:fake_notifier) { double(:fake_notifier, new: fake_worker) }

        before do
          stub_const('INotify::Notifier', fake_notifier)

          allow(config).to receive(:directories).and_return(directories)
          allow(config).to receive(:adapter_options).and_return(adapter_options)
          allow(config).to receive(:silencer).and_return(silencer)
          allow(fake_worker).to receive(:close)
        end

        after do
          subject.stop
        end

        it 'starts by calling watch with default events' do
          expect(fake_worker).to receive(:watch).with(*directories.map(&:to_s), *default_events)
          subject.start
        end
      end

      describe 'inotify max watches exceeded' do
        let(:directories) { [Pathname.pwd] }
        let(:adapter_options) { {} }

        before do
          fake_worker = double(:fake_worker_for_inotify_limit_message)
          allow(fake_worker).to receive(:watch).and_raise(Errno::ENOSPC)
          allow(fake_worker).to receive(:close)

          fake_notifier = double(:fake_notifier, new: fake_worker)
          stub_const('INotify::Notifier', fake_notifier)

          allow(config).to receive(:directories).and_return(directories)
          allow(config).to receive(:adapter_options).and_return(adapter_options)
        end

        it 'raises exception' do
          expect { subject.start }.to raise_exception(Listen::Error::INotifyMaxWatchesExceeded, /inotify max watches exceeded/i)
        end
      end

      # TODO: should probably be adapted to be more like adapter/base_spec.rb
      describe '_callback' do
        let(:directories) { [dir1] }
        let(:adapter_options) { { events: [:recursive, :close_write] } }

        before do
          fake_worker = double(:fake_worker_for_callback)
          events = [:recursive, :close_write]
          allow(fake_worker).to receive(:watch).with('/foo/dir1', *events)
          allow(fake_worker).to receive(:close)

          fake_notifier = double(:fake_notifier, new: fake_worker)
          stub_const('INotify::Notifier', fake_notifier)

          allow(config).to receive(:directories).and_return(directories)
          allow(config).to receive(:adapter_options).and_return(adapter_options)
          allow(config).to receive(:silencer).and_return(silencer)

          allow(Listen::Record).to receive(:new).with(dir1, silencer).and_return(record)
          allow(Listen::Change::Config).to receive(:new).with(queue, silencer).
            and_return(config)
          allow(Listen::Change).to receive(:new).with(config, record).
            and_return(snapshot)

          allow(subject).to receive(:require).with('rb-inotify')
          subject.configure
        end

        let(:expect_change) do
          lambda do |change|
            expect(snapshot).to receive(:invalidate).with(
              :file,
              'path/foo.txt',
              cookie: 123,
              change: change
            )
          end
        end

        let(:event_callback) do
          lambda do |flags|
            callbacks = subject.instance_variable_get(:'@callbacks')
            callbacks.values.flatten.each do |callback|
              callback.call double(
                :inotify_event,
                name: 'foo.txt',
                watcher: double(:watcher, path: '/foo/dir1/path'),
                flags: flags,
                cookie: 123)
            end
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

      describe '#stop' do
        let(:fake_worker) { double(:fake_worker_for_stop, close: true) }
        let(:directories) { [dir1] }
        let(:adapter_options) { { events: [:recursive, :close_write] } }

        before do
          allow(config).to receive(:directories).and_return(directories)
          allow(config).to receive(:adapter_options).and_return(adapter_options)
        end

        context 'when configured' do
          before do
            events = [:recursive, :close_write]
            allow(fake_worker).to receive(:watch).with('/foo/dir1', *events)

            fake_notifier = double(:fake_notifier, new: fake_worker)
            stub_const('INotify::Notifier', fake_notifier)

            allow(config).to receive(:silencer).and_return(silencer)

            allow(subject).to receive(:require).with('rb-inotify')
            subject.configure
          end

          it 'stops the worker' do
            subject.stop
          end
        end

        context 'when not even initialized' do
          before do
            allow(queue).to receive(:close)
          end

          it 'does not crash' do
            expect do
              subject.stop
            end.to_not raise_error
          end
        end
      end
    end
  end
end
