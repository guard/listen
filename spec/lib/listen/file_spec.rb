# frozen_string_literal: true

RSpec.describe Listen::File do
  let(:record) do
    instance_double(
      Listen::Record,
      root: '/foo/bar',
      file_data: record_data,
      add_dir: true,
      update_file: true,
      unset_path: true
    )
  end

  let(:path) { Pathname.pwd }
  let(:subject) { described_class.change(record, 'file.rb') }

  around { |example| fixtures { example.run } }

  before { allow(::File).to receive(:lstat) { fail 'Not stubbed!' } }

  describe '#change' do
    let(:expected_data) do
      { mtime: kind_of(Float), mode: kind_of(Integer), size: kind_of(Integer) }
    end

    context 'with file record' do
      let(:record_mtime) { nil }
      let(:record_sha) { nil }
      let(:record_mode) { nil }
      let(:record_size) { nil }

      let(:record_data) do
        { mtime: record_mtime, sha: record_sha, mode: record_mode, size: record_size }
      end

      context 'with non-existing file' do
        before { allow(::File).to receive(:lstat) { fail Errno::ENOENT } }

        it { is_expected.to eq(:removed) }

        it 'sets path in record' do
          expect(record).to receive(:unset_path).with('file.rb')
          subject
        end
      end

      context 'with existing file' do
        let(:stat_mtime) { Time.now.to_f - 1234.567 }
        let(:stat_ctime) { Time.now.to_f - 1234.567 }
        let(:stat_atime) { Time.now.to_f - 1234.567 }
        let(:stat_mode) { 0640 }

        let(:record_size) { 42 }
        let(:stat_size) { record_size }

        let(:sha) { fail 'stub me (sha)' }

        let(:stat) do
          instance_double(
            File::Stat,
            mtime: stat_mtime,
            atime: stat_atime,
            ctime: stat_ctime,
            mode: stat_mode,
            size: stat_size
          )
        end

        before do
          allow(::File).to receive(:lstat) { stat }
          allow(Digest::SHA256).to receive(:file) { double(:sha, digest: sha) }
        end

        context 'with different mode in record' do
          let(:record_mode) { 0722 }

          it { should be :modified }

          it 'sets path in record with expected data' do
            expect(record).to receive(:update_file).
              with('file.rb', expected_data)
            subject
          end
        end

        context 'with same mode in record' do
          let(:record_mode) { stat_mode }

          # e.g. file was overwritten by earlier copy
          context 'with earlier mtime than in record' do
            let(:record_mtime) { stat_mtime.to_f - 123.45 }

            it { should be :modified }

            it 'sets path in record with expected data' do
              expect(record).to receive(:update_file).
                with('file.rb', expected_data)
              subject
            end
          end

          context 'with later mtime than in record' do
            let(:record_mtime) { stat_mtime.to_f + 123.45 }

            it { should be :modified }

            it 'sets path in record with expected data' do
              expect(record).to receive(:update_file).
                with('file.rb', expected_data)
              subject
            end
          end

          context 'with identical mtime in record' do
            let(:record_mtime) { stat_mtime.to_f }

            context 'with accurate stat times' do
              let(:stat_mtime) { Time.at(1_401_235_714.123).utc }
              let(:stat_atime) { Time.at(1_401_235_714.123).utc }
              let(:stat_ctime) { Time.at(1_401_235_714.123).utc }
              let(:record_mtime) { stat_mtime.to_f }
              it { should be_nil }
            end

            context 'with inaccurate stat times' do
              let(:stat_mtime) { Time.at(1_401_235_714.0).utc }
              let(:stat_atime) { Time.at(1_401_235_714.0).utc }
              let(:stat_ctime) { Time.at(1_401_235_714.0).utc }

              let(:record_mtime) { stat_mtime.to_f }

              context 'with real mtime barely not within last second' do
                before { allow(Time).to receive(:now) { now } }

                # NOTE: if real mtime is ???14.99, the
                # saved mtime is ???14.0
                let(:now) { Time.at(1_401_235_716.00).utc }
                it { should be_nil }
              end

              context 'with real mtime barely within last second' do
                # NOTE: real mtime is in range (???14.0 .. ???14.999),
                # so saved mtime at ???14.0 means it could be
                # ???14.999, so ???15.999 could still be within 1 second
                # range
                let(:now) { Time.at(1_401_235_715.999999).utc }

                before { allow(Time).to receive(:now) { now } }

                context 'without available sha' do
                  let(:sha) { fail Errno::ENOENT }

                  # Treat it as a removed file, because chances are ...
                  # whatever is listening for changes won't be able to deal
                  # with the file either (e.g. because of permissions)
                  it { should be :removed }

                  it 'should not unset record' do
                    expect(record).to_not receive(:unset_path)
                  end
                end

                context 'with available sha' do
                  let(:sha) { 'd41d8cd98f00b204e9800998ecf8427e' }

                  context 'with same sha in record' do
                    let(:record_sha) { sha }
                    it { should be_nil }
                  end

                  context 'with no sha in record' do
                    let(:record_sha) { nil }
                    it { should be_nil }
                  end

                  context 'with different sha in record' do
                    let(:record_sha) { 'foo' }
                    it { should be :modified }

                    it 'sets path in record with expected data' do
                      expected = expected_data.merge(sha: sha)
                      expect(record).to receive(:update_file).
                        with('file.rb', expected)
                      subject
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    context 'with empty record' do
      let(:record_data) { {} }

      context 'with existing path' do
        let(:stat) do
          instance_double(
            File::Stat,
            mtime: 1234,
            mode: 0645,
            size: 0
          )
        end

        before do
          allow(::File).to receive(:lstat) { stat }
        end

        it 'returns added' do
          expect(subject).to eq :added
        end

        it 'sets path in record with expected data' do
          expect(record).to receive(:update_file).
            with('file.rb', expected_data)
          subject
        end
      end
    end
  end

  describe '#inaccurate_mac_time?' do
    let(:stat) do
      instance_double(File::Stat, mtime: mtime, atime: atime, ctime: ctime, size: 0)
    end

    subject { Listen::File.inaccurate_mac_time?(stat) }

    context 'with no accurate times' do
      let(:mtime) { Time.at(1_234_567.0).utc }
      let(:atime) { Time.at(1_234_567.0).utc }
      let(:ctime) { Time.at(1_234_567.0).utc }
      it { should be_truthy }
    end

    context 'with all accurate times' do
      let(:mtime) { Time.at(1_234_567.89).utc }
      let(:atime) { Time.at(1_234_567.89).utc }
      let(:ctime) { Time.at(1_234_567.89).utc }
      it { should be_falsey }
    end

    context 'with one accurate time' do
      let(:mtime) { Time.at(1_234_567.0).utc }
      let(:atime) { Time.at(1_234_567.89).utc }
      let(:ctime) { Time.at(1_234_567.0).utc }
      it { should be_falsey }
    end
  end
end
