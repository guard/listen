require 'spec_helper'

describe Listen::Change do
  let(:change) { Listen::Change.new(listener) }
  let(:registry) { double(Celluloid::Registry) }
  let(:listener) { double(Listen::Listener, registry: registry, options: {}) }
  let(:listener_changes) { double("listener_changes") }
  before {
    listener.stub(:changes) { listener_changes }
  }

  describe "#change" do
    let(:silencer) { double('Listen::Silencer', silenced?: false) }
    before { registry.stub(:[]).with(:silencer) { silencer } }

    context "file path" do
      context "with known change" do
        it "notifies change directly to listener" do
          expect(listener_changes).to receive(:<<).with(modified: 'file_path')
          change.change('file_path', type: 'File', change: :modified)
        end

        it "doesn't notify to listener if path is silenced" do
          # expect(silencer).to receive(:silenced?).with('file_path', 'File').and_return(true)
          expect(silencer).to receive(:silenced?).and_return(true)
          expect(listener_changes).to_not receive(:<<)

          change.change('file_path', type: 'File', change: :modified)
        end
      end

      context "with unknown change" do
        let(:file) { double('Listen::File') }
        before { Listen::File.stub(:new) { file } }

        it "calls Listen::File#change" do
          expect(Listen::File).to receive(:new).with(listener, 'file_path') { file }
          expect(file).to receive(:change)
          change.change('file_path', type: 'File')
        end

        it "doesn't call Listen::File#change if path is silenced" do
          expect(silencer).to receive(:silenced?).with('file_path', 'File').and_return(true)
          expect(Listen::File).to_not receive(:new)

          change.change('file_path', type: 'File')
        end

        context "that returns a change" do
          before { file.stub(:change) { :modified } }

          context "listener listen" do
            before { listener.stub(:listen?) { true } }

            it "notifies change to listener" do
              expect(listener_changes).to receive(:<<).with(modified: 'file_path')
              change.change('file_path', type: 'File')
            end

            context "silence option" do
              it "notifies change to listener" do
                expect(listener_changes).to_not receive(:<<)
                change.change('file_path', type: 'File', silence: true)
              end
            end
          end

          context "listener doesn't listen" do
            before { listener.stub(:listen?) { false } }

            it "notifies change to listener" do
              expect(listener_changes).to_not receive(:<<)
              change.change('file_path', type: 'File')
            end
          end
        end

        context "that returns no change" do
          before { file.stub(:change) { nil } }

          it "doesn't notifies no change" do
            expect(listener_changes).to_not receive(:<<)
            change.change('file_path', type: 'File')
          end
        end
      end
    end

    context "directory path" do
      let(:dir) { double(Listen::Directory) }
      let(:dir_options) { { type: 'Dir', recursive: true } }
      before { Listen::Directory.stub(:new) { dir } }

      it "calls Listen::Directory#scan" do
        expect(Listen::Directory).to receive(:new).with(listener, 'dir_path', dir_options) { dir }
        expect(dir).to receive(:scan)
        change.change('dir_path', dir_options)
      end
    end
  end
end
