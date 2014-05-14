require 'spec_helper'

describe Listen::Silencer do
  let(:options) { {} }

  let(:listener) do
    double(Listen::Listener,
           directories: [Pathname.pwd, Pathname.new('/Users/Shared/')],
           options: options
          )
  end

  let(:silencer) { Listen::Silencer.new(listener) }

  describe '#silenced?' do
    let(:pwd) { Pathname.pwd }

    context 'default ignore' do
      hidden_dirs = %w(.git .svn .hg .rbx .bundle)
      other_dirs = %w(bundle vendor/bundle log tmp vendor/ruby)
      (hidden_dirs + other_dirs).each do |dir|
        describe do
          let(:path) { pwd.join(dir) }

          it "silences default ignored directory: #{dir}" do
            expect(silencer.silenced?(path)).to be_true
          end

          context 'with a directory beginning with the same name' do
            let(:path) { pwd.join("#{dir}foo") }

            it "doesn't silences default ignored directory: #{dir}foo" do
              expect(silencer.silenced?(path)).to be_false
            end
          end

          context 'with a directory ending with the same name' do
            let(:path) { pwd.join("foo#{dir}") }

            it "doesn't silences default ignored directory: foo#{dir}" do
              expect(silencer.silenced?(path)).to be_false
            end
          end
        end
      end

      gedit_files = %w(.goutputstream-S3FBGX)
      kate_files = %w(foo.rbo54321.new foo.rbB22583.new foo.rb.kate-swp)
      (%w(.DS_Store foo.tmp foo~) + kate_files + gedit_files).each do |path|
        describe do
          it "by default silences files like: #{path}" do
            expect(silencer.silenced?(pwd + path)).to be_true
          end
        end
      end

      %w(foo.tmpl file.new file54321.new).each do |path|
        describe do
          it "by default does not silence files like: #{path}" do
            expect(silencer.silenced?(pwd + path)).to be_false
          end
        end
      end
    end

    context 'with ignore options (regexp)' do
      let(:options) { { ignore: /\.pid$/ } }

      it 'silences path matching custom ignore regex' do
        expect(silencer.silenced?(pwd + 'foo.pid')).to be_true
      end
    end

    context 'with ignore options (array)' do
      let(:options) { { ignore: [%r{^foo/bar}, /\.pid$/] } }

      it 'silences paths matching custom ignore regexes' do
        expect(silencer.silenced?(pwd + 'foo/bar/baz')).to be_true
        expect(silencer.silenced?(pwd + 'foo.pid')).to be_true
      end
    end

    context 'with ignore! options' do
      let(:options) { { ignore!: /\.pid$/ } }

      it 'silences custom ignored directory' do
        expect(silencer.silenced?(pwd + 'foo.pid')).to be_true
      end

      it "doesn't silence default ignored directory" do
        expect(silencer.silenced?(pwd + '.git')).to be_false
      end
    end

    context 'with only options (regexp)' do
      let(:options) { { only: %r{foo} } }

      it 'do not take only regex in account if type is Unknown' do
        expect(silencer.silenced?(pwd + 'baz')).to be_false
      end

      it 'do not silence path matches only regex if type is File' do
        expect(silencer.silenced?(pwd + 'foo', 'File')).to be_false
      end

      it 'silences other directory' do
        expect(silencer.silenced?(pwd + 'bar', 'File')).to be_true
      end
    end

    context 'with only options (array)' do
      let(:options) { { only: [%r{^foo/}, %r{\.txt$}] } }

      it 'do not take only regex in account if type is Unknown' do
        expect(silencer.silenced?(pwd + 'baz')).to be_false
      end

      it "doesn't silence good directory" do
        expect(silencer.silenced?(pwd + 'foo/bar.rb', 'File')).to be_false
      end

      it "doesn't silence good file" do
        expect(silencer.silenced?(pwd + 'bar.txt', 'File')).to be_false
      end

      it 'silences other directory' do
        expect(silencer.silenced?(pwd + 'bar/baz.rb', 'File')).to be_true
      end

      it 'silences other file' do
        expect(silencer.silenced?(pwd + 'bar.rb', 'File')).to be_true
      end
    end

    context 'with ignore and only options' do
      let(:options) { { only: /\.pid$/, ignore: %r{^bar} } }

      context 'with Unknown type' do
        context 'when not matching :only' do
          context 'when not matching :ignore' do
            it 'does not silence' do
              expect(silencer.silenced?(pwd + 'baz')).to be_false
            end
          end

          context 'when matching :ignore' do
            it 'silences' do
              expect(silencer.silenced?(pwd + 'bar')).to be_true
            end
          end
        end
      end

      context 'with File type' do
        context 'when not matching :only' do
          it 'silences' do
            expect(silencer.silenced?(pwd + 'foo.rb', 'File')).to be_true
          end
        end

        context 'when matching :only' do
          context 'when matching :ignore' do
            it 'silences' do
              expect(silencer.silenced?(pwd + 'bar.pid', 'File')).to be_true
            end
          end

          context 'when not matching :ignore' do
            it 'does not silence' do
              expect(silencer.silenced?(pwd + 'foo.pid', 'File')).to be_false
            end
          end
        end
      end
    end

    it "doesn't silence normal path" do
      path = pwd + 'some_dir' + 'some_file.rb'
      expect(silencer.silenced?(path)).to be_false
    end
  end

end
