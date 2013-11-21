require 'spec_helper'

describe Listen::Silencer do
  let(:options) { {} }
  let(:listener) { double(Listen::Listener,
    directories: [Pathname.new(Dir.pwd), Pathname.new("/Users/Shared/")],
    options: options
  ) }
  let(:silencer) { Listen::Silencer.new(listener) }

  describe "#silenced?" do
    let(:pwd) { Pathname.new(Dir.pwd) }

    context "default ignore" do
      Listen::Silencer::DEFAULT_IGNORED_DIRECTORIES.each do |dir|
        describe do
          let(:path) { pwd.join(dir) }

          it "silences default ignored directory: #{dir}" do
            expect(silencer.silenced?(path)).to be_true
          end

          context "with a directory beginning with the same name" do
            let(:path) { pwd.join("#{dir}foo") }

            it "doesn't silences default ignored directory: #{dir}foo" do
              expect(silencer.silenced?(path)).to be_false
            end
          end

          context "with a directory ending with the same name" do
            let(:path) { pwd.join("foo#{dir}") }

            it "doesn't silences default ignored directory: foo#{dir}" do
              expect(silencer.silenced?(path)).to be_false
            end
          end
        end
      end

      Listen::Silencer::DEFAULT_IGNORED_EXTENSIONS.each do |extension|
        describe do
          let(:path) { pwd.join(extension) }

          it "silences default ignored extension: #{extension}" do
            expect(silencer.silenced?(path)).to be_true
          end
        end
      end
    end

    context 'with ignore options (regexp)' do
      let(:options) { { ignore: /\.pid$/ } }

      it "silences path matching custom ignore regex" do
        expect(silencer.silenced?(pwd.join('foo.pid'))).to be_true
      end
    end

    context 'with ignore options (array)' do
      let(:options) { { ignore: [%r{^foo/bar}, /\.pid$/] } }

      it "silences paths matching custom ignore regexes" do
        expect(silencer.silenced?(pwd.join('foo/bar/baz'))).to be_true
        expect(silencer.silenced?(pwd.join('foo.pid'))).to be_true
      end
    end

    context "with ignore! options" do
      let(:options) { { ignore!: /\.pid$/ } }

      it "silences custom ignored directory" do
        expect(silencer.silenced?(pwd.join('foo.pid'))).to be_true
      end

      it "doesn't silence default ignored directory" do
        path = pwd.join(Listen::Silencer::DEFAULT_IGNORED_DIRECTORIES.first)
        expect(silencer.silenced?(path)).to be_false
      end
    end

    context "with only options (regexp)" do
      let(:options) { { only: %r{foo} } }

      it "do not take only regex in account if type is Unknown" do
        path = pwd.join('baz')
        expect(silencer.silenced?(path)).to be_false
      end

      it "do not silence path matches only regex if type is File" do
        path = pwd.join('foo')
        expect(silencer.silenced?(path, 'File')).to be_false
      end

      it "silences other directory" do
        path = pwd.join('bar')
        expect(silencer.silenced?(path, 'File')).to be_true
      end
    end

    context "with only options (array)" do
      let(:options) { { only: [%r{^foo/}, %r{\.txt$}] } }

      it "do not take only regex in account if type is Unknown" do
        expect(silencer.silenced?(pwd.join('baz'))).to be_false
      end

      it "doesn't silence good directory" do
        expect(silencer.silenced?(pwd.join('foo/bar.rb'), 'File')).to be_false
      end

      it "doesn't silence good file" do
        expect(silencer.silenced?(pwd.join('bar.txt'), 'File')).to be_false
      end

      it "silences other directory" do
        expect(silencer.silenced?(pwd.join('bar/baz.rb'), 'File')).to be_true
      end

      it "silences other file" do
        expect(silencer.silenced?(pwd.join('bar.rb'), 'File')).to be_true
      end
    end

    context 'with ignore and only options' do
      let(:options) { { only: /\.pid$/, ignore: %r{^bar} } }

      it "do not take only regex in account if type is Unknown" do
        expect(silencer.silenced?(pwd.join('baz'))).to be_false
      end

      it "do not take only regex in account if type is Unknown but silences if ignore regex matches path" do
        expect(silencer.silenced?(pwd.join('bar'))).to be_true
      end

      it 'silences path not matching custom only regex' do
        expect(silencer.silenced?(pwd.join('foo.rb'), 'File')).to be_true
      end

      it 'silences path matching custom ignore regex' do
        expect(silencer.silenced?(pwd.join('bar.pid', 'File'))).to be_true
      end

      it 'do not silence path matching custom only regex and not matching custom ignore regex' do
        expect(silencer.silenced?(pwd.join('foo.pid', 'File'))).to be_false
      end
    end

    it "doesn't silence normal path" do
      path = pwd.join('some_dir', 'some_file.rb')
      expect(silencer.silenced?(path)).to be_false
    end
  end

end
