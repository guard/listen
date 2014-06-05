require 'spec_helper'

describe Listen::Change do
  let(:subject) { Listen::Change.new(listener) }
  let(:listener) { instance_double(Listen::Listener, options: {}) }
  let(:record) { instance_double(Listen::Record) }
  let(:full_file_path) { instance_double(Pathname, to_s: '/dir/file.rb') }
  let(:full_dir_path) { instance_double(Pathname, to_s: '/dir') }
  let(:dir) { instance_double(Pathname) }

  before do
    allow(listener).to receive(:sync).with(:record) { record }
    allow(listener).to receive(:async).with(:change_pool) { subject }
    allow(dir).to receive(:+).with('file.rb') { full_file_path }
    allow(dir).to receive(:+).with('dir1') { full_dir_path }
  end

  describe '#change' do
    let(:silencer) { instance_double(Listen::Silencer, silenced?: false) }
    before { allow(listener).to receive(:silencer) { silencer } }

    context 'with build options' do
      it 'calls still_building! on record' do
        allow(listener).to receive(:queue)
        allow(record).to receive(:async) { async_record }
        allow(Listen::File).to receive(:change)
        subject.change(:file, dir, 'file.rb', build: true)
      end
    end

    context 'file' do
      context 'with known change' do
        it 'notifies change directly to listener' do
          expect(listener).to receive(:queue).
            with(:file, :modified, dir, 'file.rb', {})

          subject.change(:file, dir, 'file.rb', change: :modified)
        end

        it "doesn't notify to listener if path is silenced" do
          expect(silencer).to receive(:silenced?).and_return(true)
          expect(listener).to_not receive(:queue)
          subject.change(:file, dir, 'file.rb', change: :modified)
        end
      end

      context 'with unknown change' do

        it 'calls Listen::File#change' do
          expect(Listen::File).to receive(:change).with(record, dir, 'file.rb')
          subject.change(:file, dir, 'file.rb')
        end

        it "doesn't call Listen::File#change if path is silenced" do
          expect(silencer).to receive(:silenced?).
            with(Pathname('file.rb'), :file).and_return(true)

          expect(Listen::File).to_not receive(:change)
          subject.change(:file, dir, 'file.rb')
        end

        context 'that returns a change' do
          before { allow(Listen::File).to receive(:change) { :modified } }

          context 'listener listen' do
            it 'notifies change to listener' do
              expect(listener).to receive(:queue).
                with(:file, :modified, dir, 'file.rb')

              subject.change(:file, dir, 'file.rb')
            end

            context 'silence option' do
              it 'notifies change to listener' do
                expect(listener).to_not receive(:queue)
                subject.change(:file, dir, 'file.rb', silence: true)
              end
            end
          end
        end

        context 'that returns no change' do
          before { allow(Listen::File).to receive(:change) { nil } }

          it "doesn't notifies no change" do
            expect(listener).to_not receive(:queue)
            subject.change(:file, dir, 'file.rb')
          end
        end
      end
    end

    context 'directory' do
      let(:dir_options) { { recursive: true } }

      it 'calls Listen::Directory#new' do
        expect(Listen::Directory).to receive(:scan).
          with(subject, record, dir, 'dir1', dir_options)

        subject.change(:dir, dir, 'dir1', dir_options)
      end
    end
  end
end
