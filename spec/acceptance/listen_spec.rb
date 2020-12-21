# frozen_string_literal: true

RSpec.describe 'Listen', acceptance: true do
  let(:base_options) { { latency: 0.1 } }
  let(:polling_options) { {} }
  let(:options) { {} }
  let(:all_options) { base_options.merge(polling_options).merge(options) }

  let(:wrapper) { setup_listener(all_options, :track_changes) }

  context 'with normal start/stop' do
    before { wrapper.listener.start }
    after { wrapper.listener.stop }

    subject { wrapper }

    context 'with one listen dir' do
      let(:paths) { Pathname.new(Dir.pwd) }
      around { |example| fixtures { example.run } }

      modes =
        case ENV['TEST_LISTEN_ADAPTER_MODES']
        when 'polling'
          [true]
        when 'native'
          [false]
        else
          [false, true]
        end

      # TODO: make it configurable
      # TODO: restore
      modes.each do |polling|
        context "force_polling option to #{polling}" do
          let(:polling_options) { { force_polling: polling } }

          if polling
            context 'when polling' do
              context 'with a large latency' do
                let(:options) { { latency: 10 } }
                it 'passes the latency option correctly' do
                  expect(subject).to_not process_addition_of('file.rb')
                end
              end
            end
          else
            unless darwin?
              context 'when driver does not support option' do
                let(:options) { { latency: 10 } }
                it 'does not pass the latency option' do
                  expect(subject).to process_addition_of('file.rb')
                end
              end
            end
          end

          context 'with default ignore options' do
            context 'with nothing in listen dir' do
              it { is_expected.to process_addition_of('file.rb') }
              it { is_expected.to process_addition_of('.hidden') }

              it 'listens to multiple files addition' do
                result = wrapper.listen do
                  change_fs(:added, 'file1.rb')
                  change_fs(:added, 'file2.rb')
                end

                expect(result).to eq(modified: [],
                                     added: %w[file1.rb file2.rb],
                                     removed: [])
              end

              it 'listens to file moved inside' do
                touch '../file.rb'
                expect(wrapper.listen do
                  mv '../file.rb', 'file.rb'
                end).to eq(modified: [], added: ['file.rb'], removed: [])
              end
            end

            context 'existing file.rb in listen dir' do
              around do |example|
                change_fs(:added, 'file.rb')
                example.run
              end

              it { is_expected.to process_modification_of('file.rb') }
              it { is_expected.to process_removal_of('file.rb') }

              it 'listens to file.rb moved out' do
                expect(wrapper.listen do
                  mv 'file.rb', '../file.rb'
                end).to eq(modified: [], added: [], removed: ['file.rb'])
              end

              it 'listens to file mode change' do
                prev_mode = File.stat('file.rb').mode

                result = wrapper.listen do
                  windows? ? `attrib +r file.rb` : chmod(0444, 'file.rb')
                end

                new_mode = File.stat('file.rb').mode
                no_event = result[:modified].empty? && prev_mode == new_mode

                # Check if chmod actually works or an attrib event happens,
                # or expect nothing otherwise
                #
                # (e.g. fails for polling+vfat on Linux, but works with
                # INotify+vfat because you get an event regardless if mode
                # actually changes)
                #
                files = no_event ? [] : ['file.rb']

                expect(result).to eq(modified: files, added: [], removed: [])
              end
            end

            context 'hidden file in listen dir' do
              around do |example|
                change_fs(:added, '.hidden')
                example.run
              end

              it { is_expected.to process_modification_of('.hidden') }
            end

            context 'dir in listen dir' do
              around do |example|
                mkdir_p 'dir'
                example.run
              end

              it { is_expected.to process_addition_of('dir/file.rb') }
            end

            context 'dir with file in listen dir' do
              around do |example|
                mkdir_p 'dir'
                touch 'dir/file.rb'
                example.run
              end

              it 'listens to file move' do
                expected = { modified: [],
                             added: %w[file.rb],
                             removed: %w[dir/file.rb] }

                expect(wrapper.listen do
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

                expect(wrapper.listen do
                  mv 'dir1/file1.rb', 'dir2/file1.rb'
                  mv 'dir2/file2.rb', 'dir1/file2.rb'
                end).to eq expected
              end

              it 'listens to dir move' do
                expected = { modified: [],
                             added: ['dir2/dir1/file1.rb'],
                             removed: ['dir1/file1.rb'] }

                expect(wrapper.listen do
                  mv 'dir1', 'dir2/'
                end).to eq expected
              end
            end

            context 'listens to subdirectory removed' do
              around do |example|
                mkdir_p 'dir1'
                mkdir_p 'dir1/subdir1'
                mkdir_p 'dir1/subdir1/subdir2'
                touch 'dir1/subdir1/file.rb'
                touch 'dir1/subdir1/subdir2/file.rb'
                example.run
              end

              it 'listen to the files of a removed directory' do
                expected = {
                  modified: [],
                  added:    [],
                  removed:  %w[dir1/subdir1/file.rb dir1/subdir1/subdir2/file.rb]
                }

                expect(wrapper.listen do
                  rm_rf 'dir1'
                end).to eq expected
              end
            end

            context 'listens to sub-subdirectory removed' do
              around do |example|
                mkdir_p 'dir1'
                mkdir_p 'dir1/subdir1'
                mkdir_p 'dir1/subdir1/subdir2'
                touch 'dir1/subdir1/file.rb'
                touch 'dir1/subdir1/subdir2/file.rb'
                example.run
              end

              it 'listen to the files of a removed directory' do
                expected = {
                  modified: [],
                  added:    [],
                  removed:  %w[dir1/subdir1/file.rb dir1/subdir1/subdir2/file.rb]
                }

                expect(wrapper.listen do
                  rm_rf 'dir1/subdir1'
                end).to eq expected
              end
            end

            context 'with .bundle dir ignored by default' do
              around do |example|
                mkdir_p '.bundle'
                example.run
              end

              it { is_expected.not_to process_addition_of('.bundle/file.rb') }
            end
          end

          context 'when :ignore is *ignored_dir*' do
            context 'ignored dir with file in listen dir' do
              let(:options) { { ignore: /ignored_dir/ } }

              around do |example|
                mkdir_p 'ignored_dir'
                example.run
              end

              it { is_expected.not_to process_addition_of('ignored_dir/file.rb') }
            end

            context 'when :only is *.rb' do
              let(:options) { { only: /\.rb$/ } }

              it { is_expected.to process_addition_of('file.rb') }
              it { is_expected.not_to process_addition_of('file.txt') }
            end

            context 'when :ignore is bar.rb' do
              context 'when :only is *.rb' do
                let(:options) { { ignore: /bar\.rb$/, only: /\.rb$/ } }

                it { is_expected.to process_addition_of('file.rb') }
                it { is_expected.not_to process_addition_of('file.txt') }
                it { is_expected.not_to process_addition_of('bar.rb') }
              end
            end

            context 'when default ignore is *.rb' do
              let(:options) { { ignore: /\.rb$/ } }

              it { is_expected.not_to process_addition_of('file.rb') }

              context 'with #ignore on *.txt mask' do
                before { wrapper.listener.ignore(/\.txt/) }

                it { is_expected.not_to process_addition_of('file.rb') }
                it { is_expected.not_to process_addition_of('file.txt') }
              end

              context 'with #ignore! on *.txt mask' do
                before { wrapper.listener.ignore!(/\.txt/) }

                it { is_expected.to process_addition_of('file.rb') }
                it { is_expected.not_to process_addition_of('file.txt') }
              end
            end
          end
        end
      end
    end

    context 'with paths set' do
      let(:paths) { Pathname.new(Dir.pwd) }

      it 'allows extra calls to stop' do
        wrapper.listener.stop
        wrapper.listener.stop
      end
    end
  end

  context 'when never started' do
    let(:paths) { Pathname.new(Dir.pwd) }

    it 'allows stop' do
      wrapper.listener.stop
    end

    it 'extra calls to stop' do
      wrapper.listener.stop
      wrapper.listener.stop
      wrapper.listener.stop
    end
  end
end
