require 'spec_helper'

describe Listen::DirectoryRecord do
  let(:base_directory) { Dir.tmpdir }

  subject { described_class.new(base_directory) }

  describe '#initialize' do
    it 'sets the base directory' do
      subject.directory.should eq base_directory
    end

    it 'sets the default ignored paths' do
      subject.ignored_paths.should =~ described_class::DEFAULT_IGNORED_PATHS
    end

    it 'sets the default filters' do
      subject.filters.should eq []
    end

    it 'raises an error when the passed path does not exist' do
      expect { described_class.new('no way I exist') }.to raise_error(ArgumentError)
    end

    it 'raises an error when the passed path is not a directory' do
      expect { described_class.new(__FILE__) }.to raise_error(ArgumentError)
    end
  end

  describe '#ignore' do
    it 'adds the passed paths to the list of ignoted paths in the record' do
      subject.ignore('.old', '.pid')
      subject.ignored_paths.should include('.old', '.pid')
    end
  end

  describe '#filter' do
    it 'adds the passed regexps to the list of filters that determine the stored paths' do
      subject.filter(%r{\.(?:jpe?g|gif|png)}, %r{\.(?:mp3|ogg|a3c)})
      subject.filters.should include(%r{\.(?:jpe?g|gif|png)}, %r{\.(?:mp3|ogg|a3c)})
    end
  end

  describe '#ignored?' do
    it 'returns true when the passed path is ignored' do
      subject.ignore('.pid')
      subject.ignored?('/tmp/some_process.pid').should be_true
    end

    it 'returns false when the passed path is not ignored' do
      subject.ignore('.pid')
      subject.ignored?('/tmp/some_file.txt').should be_false
    end
  end

  describe '#filterd?' do
    it 'returns true when the passed path is filtered' do
      subject.filter(%r{\.(?:jpe?g|gif|png)})
      subject.filtered?('/tmp/picture.jpeg').should be_true
    end

    it 'returns false when the passed path is not filtered' do
      subject.filter(%r{\.(?:jpe?g|gif|png)})
      subject.filtered?('/tmp/song.mp3').should be_false
    end
  end

  describe '#build' do
    it 'stores all files' do
      fixtures do |path|
        touch 'file.rb'
        mkdir 'a_directory'
        touch 'a_directory/file.txt'

        record = described_class.new(path)
        record.build

        record.paths[path]['file.rb'].should eq 'File'
        record.paths[path]['a_directory'].should eq 'Dir'
        record.paths["#{path}/a_directory"]['file.txt'].should eq 'File'
      end
    end

    context 'with ignored path set' do
      it 'does not store ignored directory or its childs' do
        fixtures do |path|
          mkdir 'ignored_directory'
          mkdir 'ignored_directory/child_directory'
          touch 'ignored_directory/file.txt'

          record = described_class.new(path)
          record.ignore 'ignored_directory'
          record.build

          record.paths[path]['/a_ignored_directory'].should be_nil
          record.paths["#{path}/a_ignored_directory"]['child_directory'].should be_nil
          record.paths["#{path}/a_ignored_directory"]['file.txt'].should be_nil
        end
      end

      it 'does not store ignored files' do
        fixtures do |path|
          touch 'ignored_file.rb'

          record = described_class.new(path)
          record.ignore 'ignored_file.rb'
          record.build

          record.paths[path]['ignored_file.rb'].should be_nil
        end
      end
    end

    context 'with filters set' do
      it 'only stores filterd files' do
        fixtures do |path|
          touch 'file.rb'
          touch 'file.zip'
          mkdir 'a_directory'
          touch 'a_directory/file.txt'
          touch 'a_directory/file.rb'

          record = described_class.new(path)
          record.filter(/\.txt$/, /.*\.zip/)
          record.build

          record.paths[path]['file.rb'].should be_nil
          record.paths[path]['file.zip'].should eq 'File'
          record.paths[path]['a_directory'].should eq 'Dir'
          record.paths["#{path}/a_directory"]['file.txt'].should eq 'File'
          record.paths["#{path}/a_directory"]['file.rb'].should be_nil
        end
      end
    end
  end

  describe '#fetch_changes' do
    context 'with single file changes' do
      context 'when a file is created' do
        it 'detects the added file' do
          fixtures do |path|
            modified, added, removed = changes(path) do
              touch 'new_file.rb'
            end

            added.should =~ %w(new_file.rb)
            modified.should be_empty
            removed.should be_empty
          end
        end

        it 'stores the added file in the record' do
          fixtures do |path|
            changes(path) do
              @record.paths.should be_empty

              touch 'new_file.rb'
            end

            @record.paths[path]['new_file.rb'].should_not be_nil
          end
        end

        context 'given a new created directory' do
          it 'detects the added file' do
            fixtures do |path|
              modified, added, removed = changes(path) do
                mkdir 'a_directory'
                touch 'a_directory/new_file.rb'
              end

              added.should =~ %w(a_directory/new_file.rb)
              modified.should be_empty
              removed.should be_empty
            end
          end

          it 'stores the added directory and file in the record' do
            fixtures do |path|
              changes(path) do
                @record.paths.should be_empty

                mkdir 'a_directory'
                touch 'a_directory/new_file.rb'
              end

              @record.paths[path]['a_directory'].should_not be_nil
              @record.paths["#{path}/a_directory"]['new_file.rb'].should_not be_nil
            end
          end
        end

        context 'given an existing directory' do
          context 'with recursive option set to true' do
            it 'detects the added file' do
              fixtures do |path|
                mkdir 'a_directory'

                modified, added, removed = changes(path, :recursive => true) do
                  touch 'a_directory/new_file.rb'
                end

                added.should =~ %w(a_directory/new_file.rb)
                modified.should be_empty
                removed.should be_empty
              end
            end

            context 'with an ignored directory' do
              it "doesn't detect the added file" do
                fixtures do |path|
                  mkdir 'ignored_directory'

                  modified, added, removed = changes(path, :ignore => 'ignored_directory', :recursive => true) do
                    touch 'ignored_directory/new_file.rb'
                  end

                  added.should be_empty
                  modified.should be_empty
                  removed.should be_empty
                end
              end

              it "doesn't detect the added file when it's asked to fetch the changes of the ignored directory"do
                fixtures do |path|
                  mkdir 'ignored_directory'

                  modified, added, removed = changes(path, :paths => ["#{path}/ignored_directory"], :ignore => 'ignored_directory', :recursive => true) do
                    touch 'ignored_directory/new_file.rb'
                  end

                  added.should be_empty
                  modified.should be_empty
                  removed.should be_empty
                end
              end
            end
          end

          context 'with recursive option set to false' do
            it "doesn't detect deeply-nested added files" do
              fixtures do |path|
                mkdir 'a_directory'

                modified, added, removed = changes(path, :recursive => false) do
                  touch 'a_directory/new_file.rb'
                end

                added.should be_empty
                modified.should be_empty
                removed.should be_empty
              end
            end
          end
        end
      end

      context 'when a file is modified' do
        it 'detects the modified file' do
          fixtures do |path|
            touch 'existing_file.txt'

            modified, added, removed = changes(path) do
              sleep 1.5 # make a diffrence in the mtime of the file
              touch 'existing_file.txt'
            end

            added.should be_empty
            modified.should =~ %w(existing_file.txt)
            removed.should be_empty
          end
        end

        context 'during the same second' do
          before { ensure_same_second }

          it 'always detects the modified file the first time' do
            fixtures do |path|
              touch 'existing_file.txt'

              modified, added, removed = changes(path) do
                touch 'existing_file.txt'
              end

              added.should be_empty
              modified.should =~ %w(existing_file.txt)
              removed.should be_empty
            end
          end

          it "doesn't detects the modified file the second time if the content haven't changed" do
            fixtures do |path|
              touch 'existing_file.txt'

              changes(path) do
                touch 'existing_file.txt'
              end

              modified, added, removed = changes(path, :use_last_record => true) do
                touch 'existing_file.txt'
              end

              added.should be_empty
              modified.should be_empty
              removed.should be_empty
            end
          end

          it "detects the modified file the second time if the content have changed" do
            fixtures do |path|
              touch 'existing_file.txt'

              changes(path) do
                touch 'existing_file.txt'
              end

              modified, added, removed = changes(path, :use_last_record => true) do
                open('existing_file.txt', 'w') { |f| f.write('foo') }
              end

              added.should be_empty
              modified.should =~ %w(existing_file.txt)
              removed.should be_empty
            end
          end
        end

        context 'given a hidden file' do
          it 'detects the modified file' do
            fixtures do |path|
              touch '.hidden'

              modified, added, removed = changes(path) do
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
              sleep 1.5 # make a diffrence in the mtime of the file

              modified, added, removed = changes(path) do
                chmod 0777, 'run.rb'
              end

              added.should be_empty
              modified.should be_empty
              removed.should be_empty
            end
          end
        end

        context 'given an existing directory' do
          context 'with recursive option set to true' do
            it 'detects the modified file' do
              fixtures do |path|
                mkdir 'a_directory'
                touch 'a_directory/existing_file.txt'

                modified, added, removed = changes(path, :recursive => true) do
                  touch 'a_directory/existing_file.txt'
                end

                added.should be_empty
                modified.should =~ %w(a_directory/existing_file.txt)
                removed.should be_empty
              end
            end
          end

          context 'with recursive option set to false' do
            it "doesn't detects the modified file" do
              fixtures do |path|
                mkdir 'a_directory'
                touch 'a_directory/existing_file.txt'

                modified, added, removed = changes(path, :recursive => false) do
                  touch 'a_directory/existing_file.txt'
                end

                added.should be_empty
                modified.should be_empty
                removed.should be_empty
              end
            end
          end
        end
      end

      context 'when a file is moved' do
        it 'detects the file movement' do
          fixtures do |path|
            touch 'move_me.txt'

            modified, added, removed = changes(path) do
              mv 'move_me.txt', 'new_name.txt'
            end

            added.should =~ %w(new_name.txt)
            modified.should be_empty
            removed.should =~ %w(move_me.txt)
          end
        end

        context 'given an existing directory' do
          context 'with recursive option set to true' do
            it 'detects the file movement into the directory' do
              fixtures do |path|
                mkdir 'a_directory'
                touch 'move_me.txt'

                modified, added, removed = changes(path, :recursive => true) do
                  mv 'move_me.txt', 'a_directory/move_me.txt'
                end

                added.should =~ %w(a_directory/move_me.txt)
                modified.should be_empty
                removed.should =~ %w(move_me.txt)
              end
            end

            it 'detects a file movement out of the directory' do
              fixtures do |path|
                mkdir 'a_directory'
                touch 'a_directory/move_me.txt'

                modified, added, removed = changes(path, :recursive => true) do
                  mv 'a_directory/move_me.txt', 'i_am_here.txt'
                end

                added.should =~ %w(i_am_here.txt)
                modified.should be_empty
                removed.should =~ %w(a_directory/move_me.txt)
              end
            end

            it 'detects a file movement between two directories' do
              fixtures do |path|
                mkdir 'from_directory'
                touch 'from_directory/move_me.txt'
                mkdir 'to_directory'

                modified, added, removed = changes(path, :recursive => true) do
                  mv 'from_directory/move_me.txt', 'to_directory/move_me.txt'
                end

                added.should =~ %w(to_directory/move_me.txt)
                modified.should be_empty
                removed.should =~ %w(from_directory/move_me.txt)
              end
            end
          end

          context 'with recursive option set to false' do
            it "doesn't detect the file movement into the directory" do
              fixtures do |path|
                mkdir 'a_directory'
                touch 'move_me.txt'

                modified, added, removed = changes(path, :recursive => false) do
                  mv 'move_me.txt', 'a_directory/move_me.txt'
                end

                added.should be_empty
                modified.should be_empty
                removed.should =~ %w(move_me.txt)
              end
            end

            it "doesn't detect a file movement out of the directory" do
              fixtures do |path|
                mkdir 'a_directory'
                touch 'a_directory/move_me.txt'

                modified, added, removed = changes(path, :recursive => false) do
                  mv 'a_directory/move_me.txt', 'i_am_here.txt'
                end

                added.should =~ %w(i_am_here.txt)
                modified.should be_empty
                removed.should be_empty
              end
            end

            it "doesn't detect a file movement between two directories" do
              fixtures do |path|
                mkdir 'from_directory'
                touch 'from_directory/move_me.txt'
                mkdir 'to_directory'

                modified, added, removed = changes(path, :recursive => false) do
                  mv 'from_directory/move_me.txt', 'to_directory/move_me.txt'
                end

                added.should be_empty
                modified.should be_empty
                removed.should be_empty
              end
            end

            context 'with all paths are passed as params' do
              it 'detects the file movement into the directory' do
                fixtures do |path|
                  mkdir 'a_directory'
                  touch 'move_me.txt'

                  modified, added, removed = changes(path, :recursive => false, :paths => [path, "#{path}/a_directory"]) do
                    mv 'move_me.txt', 'a_directory/move_me.txt'
                  end

                  added.should =~ %w(a_directory/move_me.txt)
                  modified.should be_empty
                  removed.should =~ %w(move_me.txt)
                end
              end

              it 'detects a file moved outside of a directory' do
                fixtures do |path|
                  mkdir 'a_directory'
                  touch 'a_directory/move_me.txt'

                  modified, added, removed = changes(path, :recursive => false, :paths => [path, "#{path}/a_directory"]) do
                    mv 'a_directory/move_me.txt', 'i_am_here.txt'
                  end

                  added.should =~ %w(i_am_here.txt)
                  modified.should be_empty
                  removed.should =~ %w(a_directory/move_me.txt)
                end
              end

              it 'detects a file movement between two directories' do
                fixtures do |path|
                  mkdir 'from_directory'
                  touch 'from_directory/move_me.txt'
                  mkdir 'to_directory'

                  modified, added, removed = changes(path, :recursive => false, :paths => [path, "#{path}/from_directory", "#{path}/to_directory"]) do
                    mv 'from_directory/move_me.txt', 'to_directory/move_me.txt'
                  end

                  added.should =~ %w(to_directory/move_me.txt)
                  modified.should be_empty
                  removed.should =~ %w(from_directory/move_me.txt)
                end
              end
            end
          end
        end
      end

      context 'when a file is deleted' do
        it 'detects the file removal' do
          fixtures do |path|
            touch 'unnecessary.txt'

            modified, added, removed = changes(path) do
              rm 'unnecessary.txt'
            end

            added.should be_empty
            modified.should be_empty
            removed.should =~ %w(unnecessary.txt)
          end
        end

        it "deletes the file from the record" do
          fixtures do |path|
            touch 'unnecessary.txt'

            changes(path) do
              @record.paths[path]['unnecessary.txt'].should_not be_nil

              rm 'unnecessary.txt'
            end

            @record.paths[path]['unnecessary.txt'].should be_nil
          end
        end

        it "deletes the path from the paths checksums" do
          fixtures do |path|
            touch 'unnecessary.txt'

            changes(path) do
              @record.sha1_checksums["#{path}/unnecessary.txt"] = 'foo'

              rm 'unnecessary.txt'
            end

            @record.sha1_checksums["#{path}/unnecessary.txt"].should be_nil
          end
        end

        context 'given an existing directory' do
          context 'with recursive option set to true' do
            it 'detects the file removal' do
              fixtures do |path|
                mkdir 'a_directory'
                touch 'a_directory/do_not_use.rb'

                modified, added, removed = changes(path, :recursive => true) do
                  rm 'a_directory/do_not_use.rb'
                end

                added.should be_empty
                modified.should be_empty
                removed.should =~ %w(a_directory/do_not_use.rb)
              end
            end
          end

          context 'with recursive option set to false' do
            it "doesn't detect the file removal" do
              fixtures do |path|
                mkdir 'a_directory'
                touch 'a_directory/do_not_use.rb'

                modified, added, removed = changes(path, :recursive => false) do
                  rm 'a_directory/do_not_use.rb'
                end

                added.should be_empty
                modified.should be_empty
                removed.should be_empty
              end
            end
          end
        end
      end
    end

    context 'multiple file operations' do
      it 'detects the added files' do
        fixtures do |path|
          modified, added, removed = changes(path) do
            touch 'a_file.rb'
            touch 'b_file.rb'
            mkdir 'a_directory'
            touch 'a_directory/a_file.rb'
            touch 'a_directory/b_file.rb'
          end

          added.should =~ %w(a_file.rb b_file.rb a_directory/a_file.rb a_directory/b_file.rb)
          modified.should be_empty
          removed.should be_empty
        end
      end

      it 'detects the modified files' do
        fixtures do |path|
          touch 'a_file.rb'
          touch 'b_file.rb'
          mkdir 'a_directory'
          touch 'a_directory/a_file.rb'
          touch 'a_directory/b_file.rb'
          sleep 1.5 # make files mtime old

          modified, added, removed = changes(path) do
            touch 'b_file.rb'
            touch 'a_directory/a_file.rb'
          end

          added.should be_empty
          modified.should =~ %w(b_file.rb a_directory/a_file.rb)
          removed.should be_empty
        end
      end

      it 'detects the removed files' do
        fixtures do |path|
          touch 'a_file.rb'
          touch 'b_file.rb'
          mkdir 'a_directory'
          touch 'a_directory/a_file.rb'
          touch 'a_directory/b_file.rb'
          sleep 1.5 # make files mtime old

          modified, added, removed = changes(path) do
            rm 'b_file.rb'
            rm 'a_directory/a_file.rb'
          end

          added.should be_empty
          modified.should be_empty
          removed.should =~ %w(b_file.rb a_directory/a_file.rb)
        end
      end
    end

    context 'single directory operations' do
      it 'detects a moved directory' do
        fixtures do |path|
          mkdir 'a_directory'
          touch 'a_directory/a_file.rb'
          touch 'a_directory/b_file.rb'

          modified, added, removed = changes(path) do
            mv 'a_directory', 'renamed'
          end

          added.should =~ %w(renamed/a_file.rb renamed/b_file.rb)
          modified.should be_empty
          removed.should =~ %w(a_directory/a_file.rb a_directory/b_file.rb)
        end
      end

      it 'detects a removed directory' do
        fixtures do |path|
          mkdir 'a_directory'
          touch 'a_directory/a_file.rb'
          touch 'a_directory/b_file.rb'

          modified, added, removed = changes(path) do
            rm_rf 'a_directory'
          end

          added.should be_empty
          modified.should be_empty
          removed.should =~ %w(a_directory/a_file.rb a_directory/b_file.rb)
        end
      end

      it "deletes the directory from the record" do
        fixtures do |path|
          mkdir 'a_directory'
          touch 'a_directory/file.rb'

          changes(path) do
            @record.paths.should have(2).paths
            @record.paths[path]['a_directory'].should_not be_nil
            @record.paths["#{path}/a_directory"]['file.rb'].should_not be_nil

            rm_rf 'a_directory'
          end

          @record.paths.should have(1).paths
          @record.paths[path]['a_directory'].should be_nil
          @record.paths["#{path}/a_directory"]['file.rb'].should be_nil
        end
      end

      context 'with nested paths' do
        it 'detects removals without crashing - #18' do
          fixtures do |path|
            mkdir_p 'a_directory/b_directory'
            touch 'a_directory/b_directory/do_not_use.rb'

            modified, added, removed = changes(path, :paths => [path, "#{path}/a_directory", "#{path}/b_directory"]) do
              rm_r 'a_directory'
            end

            added.should be_empty
            modified.should be_empty
            removed.should =~ %w(a_directory/b_directory/do_not_use.rb)
          end
        end
      end
    end

    context 'with a path outside the directory for which a record is made' do
      it "skips that path and doesn't check for changes" do
          fixtures do |path|
            modified, added, removed = changes(path, :paths => ['some/where/outside']) do
              @record.should_not_receive(:detect_additions)
              @record.should_not_receive(:detect_modifications_and_removals)

              touch 'new_file.rb'
            end

            added.should be_empty
            modified.should be_empty
            removed.should be_empty
          end
      end
    end

    context 'with the relative_paths option set to false' do
      it 'returns full paths in the changes hash' do
        fixtures do |path|
          touch 'a_file.rb'
          touch 'b_file.rb'

          modified, added, removed = changes(path, :relative_paths => false) do
            rm    'a_file.rb'
            touch 'b_file.rb'
            touch 'c_file.rb'
            mkdir 'a_directory'
            touch 'a_directory/a_file.rb'
          end

          added.should =~ ["#{path}/c_file.rb", "#{path}/a_directory/a_file.rb"]
          modified.should =~ ["#{path}/b_file.rb"]
          removed.should =~ ["#{path}/a_file.rb"]
        end
      end
    end
  end
end
