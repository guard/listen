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

    context "with ignore options" do
      let(:options) { { ignore: [%r{^foo/bar}, /\.pid$/] } }

      it "silences custom ignored directory" do
        path = pwd.join('foo', 'bar')
        expect(silencer.silenced?(path)).to be_true
      end

      it "silences custom ignored extension" do
        path = pwd.join('foo.pid')
        expect(silencer.silenced?(path)).to be_true
      end
    end

    context "with ignore! options" do
      let(:options) { { ignore!: %r{foo/bar} } }

      it "silences custom ignored directory" do
        path = pwd.join('foo', 'bar')
        expect(silencer.silenced?(path)).to be_true
      end

      it "doesn't silence default ignored directory" do
        path = pwd.join(Listen::Silencer::DEFAULT_IGNORED_DIRECTORIES.first)
        expect(silencer.silenced?(path)).to be_false
      end
    end

    it "doesn't silence normal path" do
      path = pwd.join('some_dir', 'some_file.rb')
      expect(silencer.silenced?(path)).to be_false
    end
  end

end
