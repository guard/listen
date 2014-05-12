# encoding: UTF-8
require 'spec_helper'

describe 'Listen' do
  let(:options) { {} }

  let(:callback) do
    lambda do |modified, added, removed|
      add_changes(:modified, modified)
      add_changes(:added, added)
      add_changes(:removed, removed)
    end
  end

  let(:listener) { @listener }
  before do
    @listener = setup_listener(options, callback)
    @listener.start
  end

  after { listener.stop }

  context 'with one listen dir' do
    let(:paths) { Pathname.new(Dir.pwd) }
    around { |example| fixtures { example.run } }

    context 'with change block raising' do
      let(:callback) { ->(_, _, _) { fail 'foo' } }

      it 'warns the backtrace' do
        expect(Kernel).to receive(:warn).
          with('[Listen warning]: Change block raised an exception: foo')
        expect(Kernel).to receive(:warn).with(/^Backtrace:.*/)
        listen { touch 'file.rb' }
      end
    end

    [false, true].each do |polling|
      context "force_polling option to #{polling}" do
        let(:options) { { force_polling: polling, latency: 0.1 } }

        context 'nothing in listen dir' do
          it 'listens to file addition' do
            expect(listen do
              touch 'file.rb'
            end).to eq(modified: [], added: ['file.rb'], removed: [])
          end

          it 'listens to multiple files addition' do
            result = listen do
              touch 'file1.rb'
              touch 'file2.rb'
            end

            expect(result).to eq(modified: [],
                                 added: %w(file1.rb file2.rb),
                                 removed: [])
          end

          it 'listens to file moved inside' do
            touch '../file.rb'
            expect(listen do
              mv '../file.rb', 'file.rb'
            end).to eq(modified: [], added: ['file.rb'], removed: [])
          end
        end

        context 'file in listen dir' do
          around do |example|
            touch 'file.rb'
            example.run
          end

          it 'listens to file touch' do
            expect(listen do
              touch 'file.rb'
            end).to eq(modified: ['file.rb'], added: [], removed: [])
          end

          it 'listens to file modification' do
            expect(listen do
              open('file.rb', 'w') { |f| f.write('foo') }
            end).to eq(modified: ['file.rb'], added: [], removed: [])
          end

          it 'listens to file modification and wait' do
            expect(listen do
              open('file.rb', 'w') { |f| f.write('foo') }
              sleep 0.5
            end).to eq(modified: ['file.rb'], added: [], removed: [])
          end

          it 'listens to file echo' do
            expect(listen do
              `echo  foo > #{Dir.pwd}/file.rb`
            end).to eq(modified: ['file.rb'], added: [], removed: [])
          end

          it 'listens to file removal' do
            expect(listen do
              rm 'file.rb'
            end).to eq(modified: [], added: [], removed: ['file.rb'])
          end

          it 'listens to file moved out' do
            expect(listen do
              mv 'file.rb', '../file.rb'
            end).to eq(modified: [], added: [], removed: ['file.rb'])
          end

          it 'listens to file mode change' do
            expect(listen do
              chmod 0777, 'file.rb'
            end).to eq(modified: ['file.rb'], added: [], removed: [])
          end
        end

        context 'hidden file in listen dir' do
          around do |example|
            touch '.hidden'
            example.run
          end

          it 'listens to file touch' do
            expect(listen do
              touch '.hidden'
            end).to eq(modified: ['.hidden'], added: [], removed: [])
          end
        end

        context 'dir in listen dir' do
          around do |example|
            mkdir_p 'dir'
            example.run
          end

          it 'listens to file touch' do
            expect(listen do
              touch 'dir/file.rb'
            end).to eq(modified: [], added: ['dir/file.rb'], removed: [])
          end
        end

        context 'dir with file in listen dir' do
          around do |example|
            mkdir_p 'dir'
            touch 'dir/file.rb'
            example.run
          end

          it 'listens to file move' do
            expected = { modified: [],
                         added: %w(file.rb),
                         removed: %w(dir/file.rb)
            }

            expect(listen do
              mv 'dir/file.rb', 'file.rb'
            end).to eq expected
          end
        end

        context 'two dirs with files in listen dir' do
          around do |example|
            mkdir_p 'dir1'
            touch 'dir1/file1.rb'
            mkdir_p 'dir2'
            touch 'dir2/file2.rb'
            example.run
          end

          it 'listens to multiple file moves' do
            expected = {
              modified: [],
              added: ['dir1/file2.rb', 'dir2/file1.rb'],
              removed: ['dir1/file1.rb', 'dir2/file2.rb']
            }

            expect(listen do
              mv 'dir1/file1.rb', 'dir2/file1.rb'
              mv 'dir2/file2.rb', 'dir1/file2.rb'
            end).to eq expected
          end

          it 'listens to dir move' do
            expected = { modified: [],
                         added: ['dir2/dir1/file1.rb'],
                         removed: ['dir1/file1.rb'] }

            expect(listen do
              mv 'dir1', 'dir2/'
            end).to eq expected
          end
        end

        context 'default ignored dir with file in listen dir' do
          around do |example|
            mkdir_p '.bundle'
            touch '.bundle/file.rb'
            example.run
          end

          let(:options) { { force_polling: polling, latency: 0.1 } }

          it "doesn't listen to file touch" do
            expect(listen do
              touch '.bundle/file.rb'
            end).to eq(modified: [], added: [], removed: [])
          end
        end

        context 'ignored dir with file in listen dir' do
          around do |example|
            mkdir_p 'ignored_dir'
            touch 'ignored_dir/file.rb'
            example.run
          end

          let(:options) do
            { force_polling: polling,
              latency: 0.1,
              ignore: /ignored_dir/ }
          end

          it "doesn't listen to file touch" do
            expect(listen do
              touch 'ignored_dir/file.rb'
            end).to eq(modified: [], added: [], removed: [])
          end
        end

        context 'with ignored file in listen dir' do
          around do |example|
            touch 'file.rb'
            example.run
          end
          let(:options) do
            { force_polling: polling,
              latency: 0.1,
              ignore: /\.rb$/ }
          end

          it "doesn't listen to file touch" do
            expect(listen do
              touch 'file.rb'
            end).to eq(modified: [], added: [], removed: [])
          end
        end

        context 'with only option' do
          let(:options) do
            { force_polling: polling,
              latency: 0.1,
              only: /\.rb$/ }
          end

          it 'listens only to file touch matching with only patterns' do
            expect(listen do
              touch 'file.rb'
              touch 'file.txt'
            end).to eq(modified: [], added: ['file.rb'], removed: [])
          end
        end

        context 'with ignore and only option' do
          let(:options) do
            { force_polling: polling,
              latency: 0.1,
              ignore: /bar\.rb$/, only: /\.rb$/ }
          end

          it 'listens only to file touch matching with only patterns' do
            expect(listen do
              touch 'file.rb'
              touch 'bar.rb'
              touch 'file.txt'
            end).to eq(modified: [], added: ['file.rb'], removed: [])
          end
        end

        describe '#ignore' do
          around do |example|
            touch 'file.rb'
            example.run
          end
          let(:options) do
            { force_polling: polling,
              latency: 0.1,
              ignore: /\.rb$/ }
          end

          it 'overwrites existing patterns' do
            expect(listen do
              listener.ignore(/\.txt/)
              touch 'file.rb'
              touch 'file.txt'
            end).to eq(modified: [], added: [], removed: [])
          end
        end

        describe '#ignore!' do
          let(:options) do
            { force_polling: polling,
              latency: 0.1,
              ignore: /\.rb$/ }
          end

          it 'overwrites existing patterns' do
            expect(listen do
              listener.ignore!(/\.txt/)
              touch 'file.rb'
              touch 'file.txt'
            end).to eq(modified: [], added: ['file.rb'], removed: [])
          end
        end
      end
    end
  end
end
