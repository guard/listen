require 'spec_helper'

describe Listen::File do
  let(:async_record) do
    instance_double(
      Listen::Record,
      set_path: true,
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
  let(:file_path) { path + 'file.rb' }
  let(:subject) { described_class.change(record, file_path) }

  around { |example| fixtures { example.run } }

  before { allow(::File).to receive(:lstat) { fail 'Not stubbed!' } }

  describe '#change' do
    let(:expected_data) do
      { type: 'File', mtime: kind_of(Float), mode: kind_of(Integer) }
    end

    context 'path present in record' do
      let(:record_mtime) { nil }
      let(:record_md5) { nil }
      let(:record_mode) { nil }

      let(:record_data) do
        { type: 'File',
          mtime: record_mtime,
          md5: record_md5,
          mode: record_mode }
      end

      context 'non-existing path' do
        before do
          allow(::File).to receive(:lstat) { fail Errno::ENOENT }
        end

        it 'returns added' do
          expect(subject).to eq :removed
        end
        it 'sets path in record' do
          expect(async_record).to receive(:unset_path).with(file_path)
          subject
        end
      end

      context 'with file modified just now' do

        context 'with old record path mtime earlier than now' do
          let(:record_mtime) { (Time.now - 1).to_f }

          let(:stat) do
            instance_double(
              File::Stat,
              mtime: record_mtime + 1,
              mode: 0640
            )
          end

          before do
            allow(File).to receive(:lstat) { stat }
          end

          it 'returns modified' do
            expect(subject).to eq :modified
          end

          it 'sets path in record with expected data' do
            expect(async_record).to receive(:set_path).
              with(file_path, expected_data)

            subject
          end
        end

        context 'with same record path mtime' do
          let(:record_mtime) { 230498230.234 }
          let(:record_mode)  { 0644 }

          let(:stat) do
            instance_double(
              File::Stat,
              mtime: 230498230.234,
              mode: 0644
            )
          end

          before do
            allow(File).to receive(:lstat) { stat }
          end

          context 'with same record path mode' do
            it 'returns nil' do
              expect(subject).to be_nil
            end
          end

          context 'with different record path mode' do
            let(:record_mode) { 'foo' }

            it 'returns modified' do
              expect(subject).to eq :modified
            end
          end

          context 'same record path md5' do
            it 'returns nil' do
              expect(subject).to be_nil
            end
          end

          if darwin?
            context 'different record path md5' do
              let(:record_md5) { 'foo' }
              let(:expected_data) do
                { type: 'File',
                  mtime: kind_of(Float),
                  mode: kind_of(Integer),
                  md5: kind_of(String) }
              end

              it 'returns modified' do
                expect(subject).to eq :modified
              end

              it 'sets path in record with expected data' do
                expect(async_record).to receive(:set_path).
                  with(file_path, expected_data)

                subject
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
          expect(async_record).to receive(:set_path).
            with(file_path, expected_data)

          subject
        end
      end
    end
  end

end
