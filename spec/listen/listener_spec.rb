require 'spec_helper'

describe Listen::Listener do

  describe '#initialize' do
    context 'with just one dir params' do
      subject { new('path') }

      it "set directory" do
        subject.directory.should eq 'path'
      end

      it "set default ignored paths" do
        subject.ignored_paths.should eq %w[.bundle .git log tmp vendor]
      end

      it "set none file filters" do
        subject.file_filters.should eq []
      end
    end

    context 'with ignored paths and file filters params' do
      subject { new('path', :ignore => '.ssh', :filter => [/.*\.rb/,/.*\.md/]) }

      it "set custom ignored paths" do
        subject.ignored_paths.should eq %w[.bundle .git log tmp vendor .ssh]
      end

      it "set custom file filters" do
        subject.file_filters.should eq [/.*\.rb/,/.*\.md/]
      end
    end

    it "selects and initializes an adapter" do
      Listen::Adapter.should_receive(:select_and_initialize)
      new('path')
    end
  end

  describe '#start' do
    let(:adapter) { mock(Listen::Adapter, :start => true) }
    before { Listen::Adapter.stub(:select_and_initialize) { adapter } }
    subject { new('path') }

    it "inits path" do
      subject.should_receive(:init_paths)
      subject.start
    end

    it "starts adapter" do
      subject.stub(:init_paths)
      adapter.should_receive(:start)
      subject.start
    end
  end

  describe '#stop' do
    let(:adapter) { mock(Listen::Adapter) }
    before { Listen::Adapter.stub(:select_and_initialize) { adapter } }
    subject { new('path') }

    it "stops adapter" do
      adapter.should_receive(:stop)
      subject.stop
    end
  end
  
  describe "#change" do
    it "set new callback block" do
      callback = lambda { |modified, added, removed| }
      listener = new('path')
      listener.change(&callback)
      listener.instance_variable_get(:@block).should eq callback
    end
  end

  describe '#ignore' do
    context 'with ignored path set on initialization' do
      it "ignores one path" do
        fixtures do |path|
          mkdir 'a_ignored_directory'
          touch 'a_ignored_directory/file.txt'

          listener = new(path, :ignore => 'a_ignored_directory')
          listener.init_paths

          listener.paths["#{path}/a_ignored_directory"]['file.txt'].should be_nil
        end
      end
    end

    context 'with ignored path set via method' do
      it "ignores one sub path" do
        fixtures do |path|
          mkdir 'a_directory'
          mkdir 'a_directory/a_ignored_directory'
          touch 'a_directory/a_ignored_directory/file.txt'

          listener = new(path)
          listener.ignore('a_directory/a_ignored_directory')
          listener.init_paths

          listener.paths["#{path}/a_directory/a_ignored_directory"]['file.txt'].should be_nil
        end
      end
    end
  end

  describe '#filter' do
    context "with no file filters set" do
      it "detects all files" do
        fixtures do |path|
          touch 'file.rb'
          mkdir 'a_directory'
          touch 'a_directory/file.txt'

          listener = new(path)
          listener.init_paths

          listener.paths[path]['file.rb'].should_not be_nil
          listener.paths["#{path}/a_directory"]['file.txt'].should_not be_nil
        end
      end
    end

    context 'with file filter set on initialization' do
      it "filters rb files" do
        fixtures do |path|
          touch 'file.rb'
          mkdir 'a_directory'
          touch 'a_directory/file.txt'
          touch 'a_directory/file.rb'

          listener = new(path, :filter => /.*\.rb/)
          listener.init_paths

          listener.paths[path]['file.rb'].should_not be_nil
          listener.paths["#{path}/a_directory"]['file.txt'].should be_nil
          listener.paths["#{path}/a_directory"]['file.rb'].should_not be_nil
        end
      end
    end

    context 'with a list file filter set via method' do
      it "filters txt and zip path" do
        fixtures do |path|
          touch 'file.rb'
          touch 'file.zip'
          mkdir 'a_directory'
          touch 'a_directory/file.txt'
          touch 'a_directory/file.rb'

          listener = new(path)
          listener.filter(/\.txt$/, /.*\.zip/)
          listener.init_paths

          listener.paths[path]['file.rb'].should be_nil
          listener.paths[path]['file.zip'].should_not be_nil
          listener.paths["#{path}/a_directory"]['file.txt'].should_not be_nil
          listener.paths["#{path}/a_directory"]['file.rb'].should be_nil
        end
      end
    end
  end

  describe '#diff' do
    context 'single file operations' do
      context 'when a file is created' do
        it 'detects the added file' do
          fixtures do |path|
            modified, added, removed = diff(path) do
              touch 'new_file.rb'
            end

            added.should =~ %w(new_file.rb)
            modified.should be_empty
            removed.should be_empty
          end
        end

        context 'given a new created directory' do
          it 'detects the added file' do
            fixtures do |path|
              modified, added, removed = diff(path) do
                mkdir 'a_directory'
                touch 'a_directory/new_file.rb'
              end

              added.should =~ %w(a_directory/new_file.rb)
              modified.should be_empty
              removed.should be_empty
            end
          end
        end

        context 'given an existing directory' do
          it 'detects the added file' do
            fixtures do |path|
              mkdir 'a_directory'

              modified, added, removed = diff(path) do
                touch 'a_directory/new_file.rb'
              end

              added.should =~ %w(a_directory/new_file.rb)
              modified.should be_empty
              removed.should be_empty
            end
          end
        end
      end

      context 'when a file is modified' do
        it 'detects the modified file' do
          fixtures do |path|
            touch 'existing_file.txt'

            modified, added, removed = diff(path) do
              sleep 1
              touch 'existing_file.txt'
            end

            added.should be_empty
            modified.should =~ %w(existing_file.txt)
            removed.should be_empty
          end
        end

        context 'given a hidden file' do
          it 'detects the modified file' do
            fixtures do |path|
              touch '.hidden'

              modified, added, removed = diff(path) do
                sleep 1
                touch '.hidden'
              end

              added.should be_empty
              modified.should =~ %w(.hidden)
              removed.should be_empty
            end
          end
        end

        context 'given a file mode change' do
          it 'does not detect the mode change' do
            fixtures do |path|
              touch 'run.rb'

              modified, added, removed = diff(path) do
                sleep 1
                chmod 0777, 'run.rb'
              end

              added.should be_empty
              modified.should be_empty
              removed.should be_empty
            end
          end
        end

        context 'given an existing directory' do
          it 'detects the modified file' do
            fixtures do |path|
              mkdir 'a_directory'
              touch 'a_directory/existing_file.txt'

              modified, added, removed = diff(path) do
                sleep 1
                touch 'a_directory/existing_file.txt'
              end

              puts added
              added.should be_empty
              modified.should =~ %w(a_directory/existing_file.txt)
              removed.should be_empty
            end
          end
        end
      end

      context 'when a file is moved' do
        it 'detects the file move' do
          fixtures do |path|
            touch 'move_me.txt'

            modified, added, removed = diff(path) do
              mv 'move_me.txt', 'new_name.txt'
            end

            added.should =~ %w(new_name.txt)
            modified.should be_empty
            removed.should =~ %w(move_me.txt)
          end
        end

        context 'given an existing directory' do
          it 'detects the file move into the directory' do
            fixtures do |path|
              mkdir 'the_directory'
              touch 'move_me.txt'

              modified, added, removed = diff(path) do
                mv 'move_me.txt', 'the_directory/move_me.txt'
              end

              added.should =~ %w(the_directory/move_me.txt)
              modified.should be_empty
              removed.should =~ %w(move_me.txt)
            end
          end

          it 'detects a file move out of the directory' do
            fixtures do |path|
              mkdir 'the_directory'
              touch 'the_directory/move_me.txt'

              modified, added, removed = diff(path) do
                mv 'the_directory/move_me.txt', 'i_am_here.txt'
              end

              added.should =~ %w(i_am_here.txt)
              modified.should be_empty
              removed.should =~ %w(the_directory/move_me.txt)
            end
          end

          it 'detects a file move between two directories' do
            fixtures do |path|
              mkdir 'from_directory'
              touch 'from_directory/move_me.txt'
              mkdir 'to_directory'

              modified, added, removed = diff(path) do
                mv 'from_directory/move_me.txt', 'to_directory/move_me.txt'
              end

              added.should =~ %w(to_directory/move_me.txt)
              modified.should be_empty
              removed.should =~ %w(from_directory/move_me.txt)
            end
          end
        end
      end

      context 'when a file is deleted' do
        it 'detects the file removal' do
          fixtures do |path|
            touch 'unnecessary.txt'

            modified, added, removed = diff(path) do
              rm 'unnecessary.txt'
            end

            added.should be_empty
            modified.should be_empty
            removed.should =~ %w(unnecessary.txt)
          end
        end

        context 'given an existing directory' do
          it 'detects the file removal' do
            fixtures do |path|
              mkdir 'a_directory'
              touch 'a_directory/do_not_use.rb'

              modified, added, removed = diff(path) do
                rm 'a_directory/do_not_use.rb'
              end

              added.should be_empty
              modified.should be_empty
              removed.should =~ %w(a_directory/do_not_use.rb)
            end
          end
        end
      end
    end

    context 'multiple file operations' do
      it 'detects the added files' do
        fixtures do |path|
          modified, added, removed = diff(path) do
            touch 'a_file.rb'
            touch 'b_file.rb'
            mkdir 'the_directory'
            touch 'the_directory/a_file.rb'
            touch 'the_directory/b_file.rb'
          end

          added.should =~ %w(a_file.rb b_file.rb the_directory/a_file.rb the_directory/b_file.rb)
          modified.should be_empty
          removed.should be_empty
        end
      end

      it 'detects the modified files' do
        fixtures do |path|
          touch 'a_file.rb'
          touch 'b_file.rb'
          mkdir 'the_directory'
          touch 'the_directory/a_file.rb'
          touch 'the_directory/b_file.rb'

          modified, added, removed = diff(path) do
            sleep 1
            touch 'b_file.rb'
            touch 'the_directory/a_file.rb'
          end

          added.should be_empty
          modified.should =~ %w(b_file.rb the_directory/a_file.rb)
          removed.should be_empty
        end
      end

      it 'detects the removed files' do
        fixtures do |path|
          touch 'a_file.rb'
          touch 'b_file.rb'
          mkdir 'the_directory'
          touch 'the_directory/a_file.rb'
          touch 'the_directory/b_file.rb'

          modified, added, removed = diff(path) do
            rm 'b_file.rb'
            rm 'the_directory/a_file.rb'
          end

          added.should be_empty
          modified.should be_empty
          removed.should =~ %w(b_file.rb the_directory/a_file.rb)
        end
      end
    end

    context 'single directory operations' do
      it 'detects a moved directory' do
        fixtures do |path|
          mkdir 'the_directory'
          touch 'the_directory/a_file.rb'
          touch 'the_directory/b_file.rb'

          modified, added, removed = diff(path) do
            mv 'the_directory', 'renamed'
          end

          added.should =~ %w(renamed/a_file.rb renamed/b_file.rb)
          modified.should be_empty
          removed.should =~ %w(the_directory/a_file.rb the_directory/b_file.rb)
        end
      end

      it 'detects a removed directory' do
        fixtures do |path|
          mkdir 'the_directory'
          touch 'the_directory/a_file.rb'
          touch 'the_directory/b_file.rb'

          modified, added, removed = diff(path) do
            rm_rf 'the_directory'
          end

          added.should be_empty
          modified.should be_empty
          removed.should =~ %w(the_directory/a_file.rb the_directory/b_file.rb)
        end
      end
    end
  end
end
