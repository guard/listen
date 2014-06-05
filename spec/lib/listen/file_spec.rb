require 'spec_helper'

describe Listen::File do
  let(:async_record) do
    instance_double(
      Listen::Record,
      add_dir: true,
      update_file: true,
      unset_path: true,
    )
  end

  let(:record) do
    instance_double(
      Listen::Record,
      async: async_record,
      file_data: record_data
    )
  end

  let(:path) { Pathname.pwd }
  let(:subject) { described_class.change(record, path, 'file.rb') }

  around { |example| fixtures { example.run } }

  before { allow(::File).to receive(:lstat) { fail 'Not stubbed!' } }

  describe '#change' do
    let(:expected_data) do
      { mtime: kind_of(Float), mode: kind_of(Integer) }
    end

    context 'with file record' do
      let(:record_mtime) { nil }
      let(:record_md5) { nil }
      let(:record_mode) { nil }

      let(:record_data) do
        { mtime: record_mtime, md5: record_md5, mode: record_mode }
      end

      context 'with non-existing file' do
        before { allow(::File).to receive(:lstat) { fail Errno::ENOENT } }

        it { should be :removed }

        it 'sets path in record' do
          expect(async_record).to receive(:unset_path).with(path, 'file.rb')
          subject
        end
      end

      context 'with existing file' do
        let(:stat_mtime) { Time.now.to_f - 1234.567 }
        let(:stat_ctime) { Time.now.to_f - 1234.567 }
        let(:stat_atime) { Time.now.to_f - 1234.567 }
        let(:stat_mode) { 0640 }
        let(:md5) { fail 'stub me (md5)' }

        let(:stat) do
          instance_double(
            File::Stat,
            mtime: stat_mtime,
            atime: stat_atime,
            ctime: stat_ctime,
            mode: stat_mode
          )
        end

        before do
          allow(::File).to receive(:lstat) { stat }
          allow(Digest::MD5).to receive(:file) { double(:md5, digest: md5) }
        end

        context 'with different mode in record' do
          let(:record_mode) { 0722 }

          it { should be :modified }

          it 'sets path in record with expected data' do
            expect(async_record).to receive(:update_file).
              with(path, 'file.rb', expected_data)
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
              expect(async_record).to receive(:update_file).
                with(path, 'file.rb', expected_data)
              subject
            end
          end

          context 'with later mtime than in record' do
            let(:record_mtime) { stat_mtime.to_f + 123.45 }

            it { should be :modified }

            it 'sets path in record with expected data' do
              expect(async_record).to receive(:update_file).
                with(path, 'file.rb', expected_data)
              subject
            end
          end

          context 'with indentical mtime in record' do
            let(:record_mtime) { stat_mtime.to_f }

            context 'with accurate stat times' do
              let(:stat_mtime) { Time.at(1401235714.123) }
              let(:stat_atime) { Time.at(1401235714.123) }
              let(:stat_ctime) { Time.at(1401235714.123) }
              let(:record_mtime) { stat_mtime.to_f }
              it { should be_nil }
            end

            context 'with inaccurate stat times' do
              let(:stat_mtime) { Time.at(1401235714.0) }
              let(:stat_atime) { Time.at(1401235714.0) }
              let(:stat_ctime) { Time.at(1401235714.0) }

              let(:record_mtime) { stat_mtime.to_f }

              context 'with real mtime barely not within last second' do
                before { allow(Time).to receive(:now) { now } }

                # NOTE: if real mtime is ???14.99, the
                # saved mtime is ???14.0
                let(:now) { Time.at(1401235716.00) }
                it { should be_nil }
              end

              context 'with real mtime barely within last second' do
                # NOTE: real mtime is in range (???14.0 .. ???14.999),
                # so saved mtime at ???14.0 means it could be
                # ???14.999, so ???15.999 could still be within 1 second
                # range
                let(:now) { Time.at(1401235715.999999) }

                before { allow(Time).to receive(:now) { now } }

                context 'without available md5' do
                  let(:md5) { fail Errno::ENOENT }

                  # Treat is as an ignored file, because chances are ...  ...
                  # whatever is listening for changes won't be able to deal
                  # with the file either (e.g. because of permissions)
                  it { should be nil }

                  it 'should not unset record' do
                    expect(async_record).to_not receive(:unset_path)
                  end
                end

                context 'with available md5' do
                  let(:md5) { 'd41d8cd98f00b204e9800998ecf8427e' }

                  context 'with same md5 in record' do
                    let(:record_md5) { md5 }
                    it { should be_nil }
                  end

                  context 'with no md5 in record' do
                    let(:record_md5) { nil }
                    it { should be_nil }
                  end

                  context 'with different md5 in record' do
                    let(:record_md5) { 'foo' }
                    it { should be :modified }

                    it 'sets path in record with expected data' do
                      expect(async_record).to receive(:update_file).
                        with(path, 'file.rb', expected_data. merge(md5: md5))
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
            mode: 0645
          )
        end

        before do
          allow(::File).to receive(:lstat) { stat }
        end

        it 'returns added' do
          expect(subject).to eq :added
        end

        it 'sets path in record with expected data' do
          expect(async_record).to receive(:update_file).
            with(path, 'file.rb', expected_data)
          subject
        end
      end
    end
  end

  describe '#inaccurate_mac_time?' do
    let(:stat) do
      instance_double(File::Stat, mtime: mtime, atime: atime, ctime: ctime)
    end

    subject { Listen::File.inaccurate_mac_time?(stat) }

    context 'with no accurate times' do
      let(:mtime) { Time.at(1234567.0) }
      let(:atime) { Time.at(1234567.0) }
      let(:ctime) { Time.at(1234567.0) }
      it { should be_truthy }
    end

    context 'with all accurate times' do
      let(:mtime) { Time.at(1234567.89) }
      let(:atime) { Time.at(1234567.89) }
      let(:ctime) { Time.at(1234567.89) }
      it { should be_falsey }
    end

    context 'with one accurate time' do
      let(:mtime) { Time.at(1234567.0) }
      let(:atime) { Time.at(1234567.89) }
      let(:ctime) { Time.at(1234567.0) }
      it { should be_falsey }
    end
  end
end
