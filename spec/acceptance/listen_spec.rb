# encoding: UTF-8
require 'spec_helper'

describe "Listen" do
  before {
    @listener = setup_listener(options)
    @listener.start
    sleep 0.25 # wait for adapter start
  }
  after {
    sleep 0.25
    @listener.stop
  }
  let(:listener) { @listener }

  context "with one listen dir" do
    let(:paths) { Pathname.new(Dir.pwd) }
    around { |example| fixtures { |path| example.run } }

    [false, true].each do |polling|
      context "force_polling option to #{polling}" do
        let(:options) { { force_polling: polling, latency: 0.1 } }

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
          around { |example| touch 'file.rb'; example.run }

          it "listens to file touch" do
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
          around { |example| touch '.hidden'; example.run }

          it "listens to file touch" do
            listen {
              touch '.hidden'
            }.should eq({ modified: ['.hidden'], added: [], removed: [] })
          end
        end

        context "dir in listen dir" do
          around { |example| mkdir_p 'dir'; example.run }

          it "listens to file touch" do
            listen {
              touch 'dir/file.rb'
            }.should eq({ modified: [], added: ['dir/file.rb'], removed: [] })
          end
        end

        context "dir with file in listen dir" do
          around { |example| mkdir_p 'dir'; touch 'dir/file.rb'; example.run }

          it "listens to file move" do
            listen {
              mv 'dir/file.rb', 'file.rb'
            }.should eq({ modified: [], added: ['file.rb'], removed: ['dir/file.rb'] })
          end
        end

        context "two dirs with files in listen dir" do
          around { |example|
            mkdir_p 'dir1'; touch 'dir1/file1.rb'
            mkdir_p 'dir2'; touch 'dir2/file2.rb'
            example.run }

          it "listens to multiple file moves" do
            listen {
              mv 'dir1/file1.rb', 'dir2/file1.rb'
              mv 'dir2/file2.rb', 'dir1/file2.rb'
            }.should eq({ modified: [], added: ['dir1/file2.rb', 'dir2/file1.rb'], removed: ['dir1/file1.rb', 'dir2/file2.rb'] })
          end

          it "listens to dir move" do
            listen {
              mv 'dir1', 'dir2/'
            }.should eq({ modified: [], added: ['dir2/dir1/file1.rb'], removed: ['dir1/file1.rb'] })
          end
        end

        context "ignored dir with file in listen dir" do
          around { |example| mkdir_p 'ignored_dir'; touch 'ignored_dir/file.rb'; example.run }
          let(:options) { { force_polling: polling, ignore: /ignored_dir/ } }

          it "doesn't listen to file touch" do
            listen {
              touch 'ignored_dir/file.rb'
            }.should eq({ modified: [], added: [], removed: [] })
          end
        end

        context "with ignored file in listen dir" do
          around { |example| touch 'file.rb'; example.run }
          let(:options) { { force_polling: polling, ignore: /\.rb$/ } }

          it "doesn't listen to file touch" do
            listen {
              touch 'file.rb'
            }.should eq({ modified: [], added: [], removed: [] })
          end
        end
      end
    end
  end
end
