require 'spec_helper'

describe Listen::Silencer do
  let(:options) { {} }

  let(:listener) do
    instance_double(
      Listen::Listener,
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
        it "silences #{dir}" do
          expect(silencer.silenced?(pwd + dir, :dir)).to be_truthy
        end

        it "doesn't silence #{dir}foo" do
          expect(silencer.silenced?(pwd + "#{dir}foo", :dir)).to be_falsey
        end

        it "doesn't silence foo#{dir}" do
          expect(silencer.silenced?(pwd + "foo#{dir}", :dir)).to be_falsey
        end
      end

      all_files = %w(.DS_Store foo.tmp foo~)

      # Gedit swap files
      all_files += %w(.goutputstream-S3FBGX)

      # Kate editor swap files
      all_files += %w(foo.rbo54321.new foo.rbB22583.new foo.rb.kate-swp)

      # Intellij swap files
      all_files += %w(foo.rb___jb_bak___ foo.rb___jb_old___)

      # Vim swap files
      all_files += %w(foo.swp foo.swx foo.swpx 4913)

      all_files.each do |path|
        it "silences #{path}" do
          expect(silencer.silenced?(pwd + path, :file)).to be_truthy
        end
      end

      %w(foo.tmpl file.new file54321.new a.swf 14913 49131).each do |path|
        it "does not silence #{path}" do
          expect(silencer.silenced?(pwd + path, :file)).to be_falsey
        end
      end
    end

    context 'with ignore options (regexp)' do
      let(:options) { { ignore: /\.pid$/ } }

      it 'silences path matching custom ignore regex' do
        expect(silencer.silenced?(pwd + 'foo.pid', :file)).to be_truthy
      end
    end

    context 'with ignore options (array)' do
      let(:options) { { ignore: [%r{^foo/bar}, /\.pid$/] } }

      it 'silences paths matching custom ignore regexes' do
        expect(silencer.silenced?(pwd + 'foo/bar/baz', :file)).to be_truthy
        expect(silencer.silenced?(pwd + 'foo.pid', :file)).to be_truthy
      end
    end

    context 'with ignore! options' do
      let(:options) { { ignore!: /\.pid$/ } }

      it 'silences custom ignored directory' do
        expect(silencer.silenced?(pwd + 'foo.pid', :file)).to be_truthy
      end

      it "doesn't silence default ignored directory" do
        expect(silencer.silenced?(pwd + '.git', :file)).to be_falsey
      end
    end

    context 'with only options (regexp)' do
      let(:options) { { only: %r{foo} } }

      it 'do not silence path matches only regex if type is File' do
        expect(silencer.silenced?(pwd + 'foo', :file)).to be_falsey
      end

      it 'silences other directory' do
        expect(silencer.silenced?(pwd + 'bar', :file)).to be_truthy
      end
    end

    context 'with only options (array)' do
      let(:options) { { only: [%r{^foo/}, %r{\.txt$}] } }

      it "doesn't silence good directory" do
        expect(silencer.silenced?(pwd + 'foo/bar.rb', :file)).to be_falsey
      end

      it "doesn't silence good file" do
        expect(silencer.silenced?(pwd + 'bar.txt', :file)).to be_falsey
      end

      it 'silences other directory' do
        expect(silencer.silenced?(pwd + 'bar/baz.rb', :file)).to be_truthy
      end

      it 'silences other file' do
        expect(silencer.silenced?(pwd + 'bar.rb', :file)).to be_truthy
      end
    end

    context 'with ignore and only options' do
      let(:options) { { only: /\.pid$/, ignore: %r{^bar} } }

      context 'with File type' do
        context 'when not matching :only' do
          it 'silences' do
            expect(silencer.silenced?(pwd + 'foo.rb', :file)).to be_truthy
          end
        end

        context 'when matching :only' do
          context 'when matching :ignore' do
            it 'silences' do
              expect(silencer.silenced?(pwd + 'bar.pid', :file)).to be_truthy
            end
          end

          context 'when not matching :ignore' do
            it 'does not silence' do
              expect(silencer.silenced?(pwd + 'foo.pid', :file)).to be_falsey
            end
          end
        end
      end
    end

    it "doesn't silence normal path" do
      path = (pwd + 'some_dir') + 'some_file.rb'
      expect(silencer.silenced?(path, :file)).to be_falsey
    end
  end

end
