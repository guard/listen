require 'spec_helper'

describe Listen::Silencer do
  let(:silencer) { Listen::Silencer.new(options) }

  describe "#silenced?" do
    let(:options) { {} }
    let(:pwd) { Pathname.new(Dir.pwd) }

    context "default ignore" do
      Listen::Silencer::DEFAULT_IGNORED_DIRECTORIES.each do |dir|
        let(:path) { pwd.join(dir) }

        it "silences default ignored directory: #{dir}" do
          silencer.silenced?(path).should be_true
        end
      end

      Listen::Silencer::DEFAULT_IGNORED_EXTENSIONS.each do |extension|
        let(:path) { pwd.join(extension) }

        it "silences default ignored extension: #{extension}" do
          silencer.silenced?(path).should be_true
        end
      end
    end

    context "with ignore options" do
      let(:options) { { ignore: [%r{foo/bar}, /\.pid$/] } }

      it "silences custom ignored directory" do
        path = pwd.join('foo', 'bar')
        silencer.silenced?(path).should be_true
      end

      it "silences custom ignored extension" do
        path = pwd.join('foo.pid')
        silencer.silenced?(path).should be_true
      end
    end

    context "with ignore! options" do
      let(:options) { { ignore!: %r{foo/bar} } }

      it "silences custom ignored directory" do
        path = pwd.join('foo', 'bar')
        silencer.silenced?(path).should be_true
      end

      it "doesn't silence default ignored directory" do
        path = pwd.join(Listen::Silencer::DEFAULT_IGNORED_DIRECTORIES.first)
        silencer.silenced?(path).should be_false
      end
    end

    it "doesn't silence normal path" do
      path = pwd.join('some_dir', 'some_file.rb')
      silencer.silenced?(path).should be_false
    end
  end

end
