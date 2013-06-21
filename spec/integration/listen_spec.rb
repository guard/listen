# encoding: UTF-8
require 'spec_helper'

def listen
  reset_changes
  @changes = { modified: [], added: [], removed: [] }
  yield
  sleep 0.2 # wait for changes
  @changes
end

def setup_listener(paths, options)
  reset_changes
  Listen.to(*paths, options) do |modified, added, removed|
    # p "changes: #{Time.now.to_f} #{modified} - #{added} - #{removed}"
    @changes[:modified] += relative_path(modified, *paths).sort
    @changes[:added]    += relative_path(added, *paths).sort
    @changes[:removed]  += relative_path(removed, *paths).sort
  end
end

def relative_path(changes, *paths)
  changes.map do |change|
    paths.flatten.each { |path| change.gsub!(%r{#{path.to_s}/}, '') }
    change
  end
end

def reset_changes
  @changes = { modified: [], added: [], removed: [] }
end

describe "Listen" do
  before {
    @listener = setup_listener(paths, options)
    @listener.start
    # p "started: #{Time.now.to_f}"
    sleep 0.2 # wait for adapter start
    sleep_until_next_second
    # p "ready to go: #{Time.now.to_f}"
  }
 after {
  sleep 0.2
  @listener.stop
}

  context "with one listen dir" do
    let(:paths) { Pathname.new(Dir.pwd) }
    around { |example| fixtures { |path| example.run } }

    context "force_polling option to true" do
      let(:options) { { force_polling: true, latency: 0.1 } }

      context "nothing in listen dir" do
        it "listens to file addition" do
          listen {
            touch 'file.rb'
          }.should eq({ modified: [], added: ['file.rb'], removed: [] })
        end

        it "listens to multiple files addition" do
          listen {
            touch 'file1.rb'
            touch 'file2.rb'
          }.should eq({ modified: [], added: ['file1.rb', 'file2.rb'], removed: [] })
        end

        it "listens to file moved inside" do
          touch '../file.rb'
          listen {
            mv '../file.rb', 'file.rb'
          }.should eq({ modified: [], added: ['file.rb'], removed: [] })
        end
      end

      context "file in listen dir" do
        around { |example|
          touch 'file.rb';
          sleep_until_next_second; example.run }

        it "listens to file touch" do
          listen {
            touch 'file.rb'
          }.should eq({ modified: ['file.rb'], added: [], removed: [] })
        end

        it "listens only once to mutltiple file touch in the same second", unless: high_file_time_precision_supported? do
          listen {
            touch 'file.rb'
          }.should eq({ modified: ['file.rb'], added: [], removed: [] })
          listen {
            touch 'file.rb'
          }.should eq({ modified: [], added: [], removed: [] })
        end

        it "listens mutltiple time to file modification in the same second" do
          listen {
            touch 'file.rb'
          }.should eq({ modified: ['file.rb'], added: [], removed: [] })
          listen {
            open('file.rb', 'w') { |f| f.write('foo') }
          }.should eq({ modified: ['file.rb'], added: [], removed: [] })
        end

        it "listens to mutltiple file touch if not in the same second" do
          listen {
            touch 'file.rb'
          }.should eq({ modified: ['file.rb'], added: [], removed: [] })
          sleep_until_next_second
          listen {
            touch 'file.rb'
          }.should eq({ modified: ['file.rb'], added: [], removed: [] })
        end

        it "listens to file modification" do
          listen {
            open('file.rb', 'w') { |f| f.write('foo') }
          }.should eq({ modified: ['file.rb'], added: [], removed: [] })
        end

        it "listens to file removal" do
          listen {
            rm 'file.rb'
          }.should eq({ modified: [], added: [], removed: ['file.rb'] })
        end

        it "listens to file moved out" do
          listen {
            mv 'file.rb', '../file.rb'
          }.should eq({ modified: [], added: [], removed: ['file.rb'] })
        end

        it "listens to file mode change" do
          listen {
            chmod 0777, 'file.rb'
          }.should eq({ modified: ['file.rb'], added: [], removed: [] })
        end
      end

      context "hidden file in listen dir" do
        around { |example|
          touch '.hidden';
          sleep_until_next_second; example.run }

        it "listens to file touch" do
          listen {
            touch '.hidden'
          }.should eq({ modified: ['.hidden'], added: [], removed: [] })
        end
      end

      context "dir in listen dir" do
        around { |example|
          mkdir_p 'dir';
          sleep_until_next_second; example.run }

        it "listens to file touch" do
          listen {
            touch 'dir/file.rb'
          }.should eq({ modified: [], added: ['dir/file.rb'], removed: [] })
        end
      end

      context "dir with file in listen dir" do
        around { |example|
          mkdir_p 'dir'; touch 'dir/file.rb';
          sleep_until_next_second; example.run }

        it "listens to file move" do
          listen {
            mv 'dir/file.rb', 'file.rb'
          }.should eq({ modified: [], added: ['file.rb'], removed: ['dir/file.rb'] })
        end
      end

      context "ignored dir with file in listen dir" do
        around { |example|
          mkdir_p 'ignored_dir'; touch 'ignored_dir/file.rb';
          sleep_until_next_second; example.run }
        let(:options) { { force_polling: true, ignore: /ignored_dir/ } }

        it "doesn't listen to file touch" do
          listen {
            touch 'ignored_dir/file.rb'
          }.should eq({ modified: [], added: [], removed: [] })
        end
      end

      context "with ignored file in listen dir" do
        around { |example| touch 'file.rb'; example.run }
        let(:options) { { force_polling: true, ignore: /\.rb$/ } }

        it "doesn't listen to file touch" do
          listen {
            touch 'file.rb'
          }.should eq({ modified: [], added: [], removed: [] })
        end
      end
    end
  end
end



#             it 'detects a file movement between two directories' do
#               fixtures do |path|
#                 mkdir 'from_directory'
#                 touch 'from_directory/move_me.txt'
#                 mkdir 'to_directory'

#                 modified, added, removed = changes(path, recursive: true) do
#                   mv 'from_directory/move_me.txt', 'to_directory/move_me.txt'
#                 end

#                 added.should =~ %w(to_directory/move_me.txt)
#                 modified.should be_empty
#                 removed.should =~ %w(from_directory/move_me.txt)
#               end
#             end
#           end

#     context 'multiple file operations' do
#       it 'detects the added files' do
#         fixtures do |path|
#           modified, added, removed = changes(path) do
#             touch 'a_file.rb'
#             touch 'b_file.rb'
#             mkdir 'a_directory'
#             touch 'a_directory/a_file.rb'
#             touch 'a_directory/b_file.rb'
#           end

#           added.should =~ %w(a_file.rb b_file.rb a_directory/a_file.rb a_directory/b_file.rb)
#           modified.should be_empty
#           removed.should be_empty
#         end
#       end

#       it 'detects the modified files' do
#         fixtures do |path|
#           touch 'a_file.rb'
#           touch 'b_file.rb'
#           mkdir 'a_directory'
#           touch 'a_directory/a_file.rb'
#           touch 'a_directory/b_file.rb'

#           modified, added, removed = changes(path) do
#             small_time_difference
#             touch 'b_file.rb'
#             touch 'a_directory/a_file.rb'
#           end

#           added.should be_empty
#           modified.should =~ %w(b_file.rb a_directory/a_file.rb)
#           removed.should be_empty
#         end
#       end

#       it 'detects the removed files' do
#         fixtures do |path|
#           touch 'a_file.rb'
#           touch 'b_file.rb'
#           mkdir 'a_directory'
#           touch 'a_directory/a_file.rb'
#           touch 'a_directory/b_file.rb'

#           modified, added, removed = changes(path) do
#             rm 'b_file.rb'
#             rm 'a_directory/a_file.rb'
#           end

#           added.should be_empty
#           modified.should be_empty
#           removed.should =~ %w(b_file.rb a_directory/a_file.rb)
#         end
#       end
#     end

#     context 'single directory operations' do
#       it 'detects a moved directory' do
#         fixtures do |path|
#           mkdir 'a_directory'
#           mkdir 'a_directory/nested'
#           touch 'a_directory/a_file.rb'
#           touch 'a_directory/b_file.rb'
#           touch 'a_directory/nested/c_file.rb'

#           modified, added, removed = changes(path) do
#             mv 'a_directory', 'renamed'
#           end

#           added.should =~ %w(renamed/a_file.rb renamed/b_file.rb renamed/nested/c_file.rb)
#           modified.should be_empty
#           removed.should =~ %w(a_directory/a_file.rb a_directory/b_file.rb a_directory/nested/c_file.rb)
#         end
#       end

#       it 'detects a removed directory' do
#         fixtures do |path|
#           mkdir 'a_directory'
#           touch 'a_directory/a_file.rb'
#           touch 'a_directory/b_file.rb'

#           modified, added, removed = changes(path) do
#             rm_rf 'a_directory'
#           end

#           added.should be_empty
#           modified.should be_empty
#           removed.should =~ %w(a_directory/a_file.rb a_directory/b_file.rb)
#         end
#       end

#       it "deletes the directory from the record" do
#         fixtures do |path|
#           mkdir 'a_directory'
#           touch 'a_directory/file.rb'

#           changes(path) do
#             @record.paths.should have(2).paths
#             @record.paths[path]['a_directory'].should_not be_nil
#             @record.paths["#{path}/a_directory"]['file.rb'].should_not be_nil

#             rm_rf 'a_directory'
#           end

#           @record.paths.should have(1).paths
#           @record.paths[path]['a_directory'].should be_nil
#           @record.paths["#{path}/a_directory"]['file.rb'].should be_nil
#         end
#       end

#       context 'with nested paths' do
#         it 'detects removals without crashing - #18' do
#           fixtures do |path|
#             mkdir_p 'a_directory/subdirectory'
#             touch   'a_directory/subdirectory/do_not_use.rb'

#             modified, added, removed = changes(path) do
#               rm_r 'a_directory'
#             end

#             added.should be_empty
#             modified.should be_empty
#             removed.should =~ %w(a_directory/subdirectory/do_not_use.rb)
#           end
#         end
#       end
#     end

#     context 'with a path outside the directory for which a record is made' do
#       it "skips that path and doesn't check for changes" do
#           fixtures do |path|
#             modified, added, removed = changes(path, paths: ['some/where/outside']) do
#               @record.should_not_receive(:detect_additions)
#               @record.should_not_receive(:detect_modifications_and_removals)

#               touch 'new_file.rb'
#             end

#             added.should be_empty
#             modified.should be_empty
#             removed.should be_empty
#           end
#       end
#     end

#     context 'with the relative_paths option set to false' do
#       it 'returns full paths in the changes hash' do
#         fixtures do |path|
#           touch 'a_file.rb'
#           touch 'b_file.rb'

#           modified, added, removed = changes(path, relative_paths: false) do
#             small_time_difference
#             rm    'a_file.rb'
#             touch 'b_file.rb'
#             touch 'c_file.rb'
#             mkdir 'a_directory'
#             touch 'a_directory/a_file.rb'
#           end

#           added.should =~ ["#{path}/c_file.rb", "#{path}/a_directory/a_file.rb"]
#           modified.should =~ ["#{path}/b_file.rb"]
#           removed.should =~ ["#{path}/a_file.rb"]
#         end
#       end
#     end

#     context 'within a directory containing unreadble paths - #32' do
#       it 'detects changes more than a second apart' do
#         fixtures do |path|
#           touch 'unreadable_file.txt'
#           chmod 000, 'unreadable_file.txt'

#           modified, added, removed = changes(path) do
#             small_time_difference
#             touch 'unreadable_file.txt'
#           end

#           added.should be_empty
#           modified.should =~ %w(unreadable_file.txt)
#           removed.should be_empty
#         end
#       end

#       context 'with multiple changes within the same second' do
#         before { ensure_same_second }

#         it 'does not detect changes even if content changes', unless: described_class::HIGH_PRECISION_SUPPORTED do
#           fixtures do |path|
#             touch 'unreadable_file.txt'

#             modified, added, removed = changes(path) do
#               open('unreadable_file.txt', 'w') { |f| f.write('foo') }
#               chmod 000, 'unreadable_file.txt'
#             end

#             added.should be_empty
#             modified.should be_empty
#             removed.should be_empty
#           end
#         end
#       end
#     end

#     context 'within a directory containing a removed file - #39' do
#       it 'does not raise an exception when hashing a removed file' do

#         # simulate a race condition where the file is removed after the
#         # change event is tracked, but before the hash is calculated
#         Digest::SHA1.should_receive(:file).twice.and_raise(Errno::ENOENT)

#         fixtures do |path|
#           lambda {
#             touch 'removed_file.txt'
#             changes(path) { touch 'removed_file.txt' }
#           }.should_not raise_error(Errno::ENOENT)
#         end
#       end
#     end

#     context 'within a directory containing a unix domain socket file' do
#       it 'does not raise an exception when hashing a unix domain socket file' do
#         fixtures do |path|
#           require 'socket'
#           UNIXServer.new('unix_domain_socket.sock')
#           lambda { changes(path){} }.should_not raise_error(Errno::ENXIO)
#         end
#       end
#     end

#     context 'with symlinks', unless: windows? do
#       it 'looks at symlinks not their targets' do
#         fixtures do |path|
#           touch 'target'
#           symlink 'target', 'symlink'

#           record = described_class.new(path)
#           record.build

#           sleep 1
#           touch 'target'

#           record.fetch_changes([path], relative_paths: true)[:modified].should == ['target']
#         end
#       end

#       it 'handles broken symlinks' do
#         fixtures do |path|
#           symlink 'target', 'symlink'

#           record = described_class.new(path)
#           record.build

#           sleep 1
#           rm 'symlink'
#           symlink 'new-target', 'symlink'
#           record.fetch_changes([path], relative_paths: true)
#         end
#       end
#     end
#   end
# end
