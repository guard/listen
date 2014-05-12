require 'spec_helper'

describe Listen::Change do
  let(:change) { Listen::Change.new(listener) }
  let(:registry) { double(Celluloid::Registry) }
  let(:listener) { double(Listen::Listener, registry: registry, options: {}) }
  let(:listener_changes) { double('listener_changes') }
  before do
    listener.stub(:changes) { listener_changes }
  end

  describe '#change' do
    let(:silencer) { double('Listen::Silencer', silenced?: false) }
    before { registry.stub(:[]).with(:silencer) { silencer } }

    context 'file path' do
      context 'with known change' do
        it 'notifies change directly to listener' do
          expect(listener_changes).to receive(:<<).
            with(modified: Pathname.new('file_path'))

          options = { type: 'File', change: :modified }
          change.change(Pathname.new('file_path'), options)
        end

        it "doesn't notify to listener if path is silenced" do
          expect(silencer).to receive(:silenced?).and_return(true)
          expect(listener_changes).to_not receive(:<<)

          options = { type: 'File', change: :modified }
          change.change(Pathname.new('file_path'), options)
        end
      end

      context 'with unknown change' do
        let(:file) { double('Listen::File') }
        before { Listen::File.stub(:new) { file } }

        it 'calls Listen::File#change' do
          expect(Listen::File).to receive(:new).
            with(listener, Pathname.new('file_path')) { file }

          expect(file).to receive(:change)
          change.change(Pathname.new('file_path'), type: 'File')
        end

        it "doesn't call Listen::File#change if path is silenced" do
          expect(silencer).to receive(:silenced?).
            with(Pathname.new('file_path'), 'File').and_return(true)

          expect(Listen::File).to_not receive(:new)

          change.change(Pathname.new('file_path'), type: 'File')
        end

        context 'that returns a change' do
          before { file.stub(:change) { :modified } }

          context 'listener listen' do
            before { listener.stub(:listen?) { true } }

            it 'notifies change to listener' do
              file_path = double(Pathname, to_s: 'file_path', exist?: true)
              expect(listener_changes).to receive(:<<).with(modified: file_path)
              change.change(file_path, type: 'File')
            end

            context 'silence option' do
              it 'notifies change to listener' do
                expect(listener_changes).to_not receive(:<<)
                options = { type: 'File', silence: true }
                change.change(Pathname.new('file_path'), options)
              end
            end
          end

          context "listener doesn't listen" do
            before { listener.stub(:listen?) { false } }

            it 'notifies change to listener' do
              expect(listener_changes).to_not receive(:<<)
              change.change(Pathname.new('file_path'), type: 'File')
            end
          end
        end

        context 'that returns no change' do
          before { file.stub(:change) { nil } }

          it "doesn't notifies no change" do
            expect(listener_changes).to_not receive(:<<)
            change.change(Pathname.new('file_path'), type: 'File')
          end
        end
      end
    end

    context 'directory path' do
      let(:dir) { double(Listen::Directory) }
      let(:dir_options) { { type: 'Dir', recursive: true } }
      before { Listen::Directory.stub(:new) { dir } }

      it 'calls Listen::Directory#scan' do
        expect(Listen::Directory).to receive(:new).
          with(listener, Pathname.new('dir_path'), dir_options) { dir }

        expect(dir).to receive(:scan)
        change.change(Pathname.new('dir_path'), dir_options)
      end
    end
  end
end
