require 'spec_helper'

describe Listen::Change do
  let(:change) { Listen::Change.new }
  let(:listener) { MockActor.new }
  let(:mailbox) { mock('mailbox', :<< => true) }
  before {
    Celluloid::Actor[:listener] = listener
    listener.stub(:mailbox) { mailbox }
  }

  describe "#change" do
    context "file path" do
      let(:file) { mock(Listen::File) }
      before { Listen::File.stub(:new) { file } }

      it "calls Listen::File#change" do
        Listen::File.should_receive(:new).with('file_path') { file }
        file.should_receive(:change)
        change.change('file_path', type: 'File')
      end

      context "that returns a change" do
        before { file.stub(:change) { :changed } }

        context "listener listen" do
          before { listener.stub(:listen?) { true } }

          it "notifies change to listener" do
            mailbox.should_receive(:<<).with(changed: 'file_path')
            change.change('file_path', type: 'File')
          end
        end

        context "listener doesn't listen" do
          before { listener.stub(:listen?) { false } }

          it "notifies change to listener" do
            mailbox.should_not_receive(:<<)
            change.change('file_path', type: 'File')
          end
        end
      end

      context "that returns no change" do
        before { file.stub(:change) { nil } }

        it "doesn't notifies no change" do
          mailbox.should_not_receive(:<<)
          change.change('file_path', type: 'File')
        end
      end
    end

    context "directory path" do
      let(:dir) { mock(Listen::Directory) }
      let(:dir_options) { { type: 'Dir', recursive: true } }
      before { Listen::Directory.stub(:new) { dir } }

      it "calls Listen::Directory#scan" do
        Listen::Directory.should_receive(:new).with('dir_path', dir_options) { dir }
        dir.should_receive(:scan)
        change.change('dir_path', dir_options)
      end
    end
  end
end
