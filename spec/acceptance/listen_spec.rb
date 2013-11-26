# encoding: UTF-8
require 'spec_helper'

describe "Listen" do
  let(:options) { { } }
  let(:callback) { ->(modified, added, removed) {
    add_changes(:modified, modified)
    add_changes(:added, added)
    add_changes(:removed, removed)
  } }
  let(:listener) { @listener }
  before {
    @listener = setup_listener(options, callback)
    @listener.start
  }
  after { listener.stop }

  context "with one listen dir" do
    let(:paths) { Pathname.new(Dir.pwd) }
    around { |example| fixtures { |path| example.run } }

    context "with change block raising" do
      let(:callback) { ->(x,y,z) { raise 'foo' } }

      it "warns the backtrace" do
        expect(Kernel).to receive(:warn).with("[Listen warning]: Change block raised an exception: foo")
        expect(Kernel).to receive(:warn).with(/^Backtrace:.*/)
        listen { touch 'file.rb' }
      end
    end

    [false, true].each do |polling|
      context "force_polling option to #{polling}" do
        let(:options) { { force_polling: polling, latency: 0.1 } }

        context "nothing in listen dir" do
          it "listens to file addition" do
            expect(listen {
              touch 'file.rb'
            }).to eq({ modified: [], added: ['file.rb'], removed: [] })
          end

          it "listens to multiple files addition" do
            expect(listen {
              touch 'file1.rb'
              touch 'file2.rb'
            }).to eq({ modified: [], added: ['file1.rb', 'file2.rb'], removed: [] })
          end

          it "listens to file moved inside" do
            touch '../file.rb'
            expect(listen {
              mv '../file.rb', 'file.rb'
            }).to eq({ modified: [], added: ['file.rb'], removed: [] })
          end
        end

        context "file in listen dir" do
          around { |example| touch 'file.rb'; example.run }

          it "listens to file touch" do
            expect(listen {
              touch 'file.rb'
            }).to eq({ modified: ['file.rb'], added: [], removed: [] })
          end

          it "listens to file modification" do
            expect(listen {
              open('file.rb', 'w') { |f| f.write('foo') }
            }).to eq({ modified: ['file.rb'], added: [], removed: [] })
          end

          it "listens to file modification and wait" do
            expect(listen {
              open('file.rb', 'w') { |f| f.write('foo') }
              sleep 0.5
            }).to eq({ modified: ['file.rb'], added: [], removed: [] })
          end

          it "listens to file echo" do
            expect(listen {
              `echo  foo > #{Dir.pwd}/file.rb`
            }).to eq({ modified: ['file.rb'], added: [], removed: [] })
          end

          it "listens to file removal" do
            expect(listen {
              rm 'file.rb'
            }).to eq({ modified: [], added: [], removed: ['file.rb'] })
          end

          it "listens to file moved out" do
            expect(listen {
              mv 'file.rb', '../file.rb'
            }).to eq({ modified: [], added: [], removed: ['file.rb'] })
          end

          it "listens to file mode change" do
            expect(listen {
              chmod 0777, 'file.rb'
            }).to eq({ modified: ['file.rb'], added: [], removed: [] })
          end
        end

        context "hidden file in listen dir" do
          around { |example| touch '.hidden'; example.run }

          it "listens to file touch" do
            expect(listen {
              touch '.hidden'
            }).to eq({ modified: ['.hidden'], added: [], removed: [] })
          end
        end

        context "dir in listen dir" do
          around { |example| mkdir_p 'dir'; example.run }

          it "listens to file touch" do
            expect(listen {
              touch 'dir/file.rb'
            }).to eq({ modified: [], added: ['dir/file.rb'], removed: [] })
          end
        end

        context "dir with file in listen dir" do
          around { |example| mkdir_p 'dir'; touch 'dir/file.rb'; example.run }

          it "listens to file move" do
            expect(listen {
              mv 'dir/file.rb', 'file.rb'
            }).to eq({ modified: [], added: ['file.rb'], removed: ['dir/file.rb'] })
          end
        end

        context "two dirs with files in listen dir" do
          around { |example|
            mkdir_p 'dir1'; touch 'dir1/file1.rb'
            mkdir_p 'dir2'; touch 'dir2/file2.rb'
            example.run }

          it "listens to multiple file moves" do
            expect(listen {
              mv 'dir1/file1.rb', 'dir2/file1.rb'
              mv 'dir2/file2.rb', 'dir1/file2.rb'
            }).to eq({ modified: [], added: ['dir1/file2.rb', 'dir2/file1.rb'], removed: ['dir1/file1.rb', 'dir2/file2.rb'] })
          end

          it "listens to dir move" do
            expect(listen {
              mv 'dir1', 'dir2/'
            }).to eq({ modified: [], added: ['dir2/dir1/file1.rb'], removed: ['dir1/file1.rb'] })
          end
        end

        context "default ignored dir with file in listen dir" do
          around { |example| mkdir_p '.bundle'; touch '.bundle/file.rb'; example.run }
          let(:options) { { force_polling: polling, latency: 0.1 } }

          it "doesn't listen to file touch" do
            expect(listen {
              touch '.bundle/file.rb'
            }).to eq({ modified: [], added: [], removed: [] })
          end
        end

        context "ignored dir with file in listen dir" do
          around { |example| mkdir_p 'ignored_dir'; touch 'ignored_dir/file.rb'; example.run }
          let(:options) { { force_polling: polling, latency: 0.1, ignore: /ignored_dir/ } }

          it "doesn't listen to file touch" do
            expect(listen {
              touch 'ignored_dir/file.rb'
            }).to eq({ modified: [], added: [], removed: [] })
          end
        end

        context "with ignored file in listen dir" do
          around { |example| touch 'file.rb'; example.run }
          let(:options) { { force_polling: polling, latency: 0.1, ignore: /\.rb$/ } }

          it "doesn't listen to file touch" do
            expect(listen {
              touch 'file.rb'
            }).to eq({ modified: [], added: [], removed: [] })
          end
        end

        context "with only option" do
          let(:options) { { force_polling: polling, latency: 0.1, only: /\.rb$/ } }

          it "listens only to file touch matching with only patterns" do
            expect(listen {
              touch 'file.rb'
              touch 'file.txt'
            }).to eq({ modified: [], added: ['file.rb'], removed: [] })
          end
        end

        context "with ignore and only option" do
          let(:options) { { force_polling: polling, latency: 0.1, ignore: /bar\.rb$/, only: /\.rb$/ } }

          it "listens only to file touch matching with only patterns" do
            expect(listen {
              touch 'file.rb'
              touch 'bar.rb'
              touch 'file.txt'
            }).to eq({ modified: [], added: ['file.rb'], removed: [] })
          end
        end

        describe "#ignore" do
          around { |example| touch 'file.rb'; example.run }
          let(:options) { { force_polling: polling, latency: 0.1, ignore: /\.rb$/ } }

          it "overwrites existing patterns" do
            expect(listen {
              listener.ignore(/\.txt/)
              touch 'file.rb'
              touch 'file.txt'
            }).to eq({ modified: [], added: [], removed: [] })
          end
        end

        describe "#ignore!" do
          let(:options) { { force_polling: polling, latency: 0.1, ignore: /\.rb$/ } }

          it "overwrites existing patterns" do
            expect(listen {
              listener.ignore!(/\.txt/)
              touch 'file.rb'
              touch 'file.txt'
            }).to eq({ modified: [], added: ['file.rb'], removed: [] })
          end
        end
      end
    end
  end
end
