require 'spec_helper'
require 'support/fixtures'

describe Listener do
  describe '.listen' do
    context 'single file operations' do
      context 'when a file is created' do
        it 'detects the added file' do
          fixtures do |path|
            modified, added, removed = listen(path) do
              touch 'new_file.rb'
            end

            added.should =~ %w(newfile.rb)
            modified.should be_empty
            removed.should be_empty
          end
        end

        context 'given a new created directory' do
          it 'detects the added file' do
            fixtures do |path|
              modified, added, removed = listen(path) do
                mkdir 'a_directory'
                touch 'a_directory/new_file.rb'
              end

              added.should =~ %w(a_directory/newfile.rb)
              modified.should be_empty
              removed.should be_empty
            end
          end
        end

        context 'given an existing directory' do
          it 'detects the added file' do
            fixtures do |path|
              mkdir 'a_directory'

              modified, added, removed = listen(path) do
                touch 'a_directory/new_file.rb'
              end

              added.should =~ %w(a_directory/newfile.rb)
              modified.should be_empty
              removed.should be_empty
            end
          end
        end
      end

      context 'when a file is modified' do
        it 'detects the modified file' do
          fixtures do |path|
            touch 'exisiting_file.txt'

            modified, added, removed = listen(path) do
              touch 'exisiting_file.txt'
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

              modified, added, removed = listen(path) do
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

              modified, added, removed = listen(path) do
                chmod 0777, 'run.rb'
              end

              added.should be_empty
              modified.should be_empty
              removed.should be_empty
            end
          end
        end

        context 'given an existing directory' do
          fixtures do |path|
            mkdir 'a_directory'
            touch 'a_directory/exisiting_file.txt'

            modified, added, removed = listen(path) do
              touch 'a_directory/exisiting_file.txt'
            end

            added.should be_empty
            modified.should =~ %w(a_directory/existing_file.txt)
            removed.should be_empty
          end

        end
      end

      context 'when a file is moved' do
        it 'detects the file move' do
          fixtures do |path|
            touch 'move_me.txt'

            modified, added, removed = listen(path) do
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

              modified, added, removed = listen(path) do
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

              modified, added, removed = listen(path) do
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

              modified, added, removed = listen(path) do
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

            modified, added, removed = listen(path) do
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

              modified, added, removed = listen(path) do
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
          modified, added, removed = listen(path) do
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

          modified, added, removed = listen(path) do
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

          modified, added, removed = listen(path) do
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

          modified, added, removed = listen(path) do
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

          modified, added, removed = listen(path) do
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
