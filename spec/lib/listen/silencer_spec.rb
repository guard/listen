require 'spec_helper'

RSpec::Matchers.define :accept do |type, path|
  match { |actual| !actual.silenced?(Pathname(path), type) }
end

describe Listen::Silencer do
  let(:options) { {} }
  before { subject.configure(options) }

  describe '#silenced?' do
    it { should accept(:file, Pathname('some_dir') + 'some_file.rb') }

    context 'with default ignore' do
      hidden_ignored = %w(.git .svn .hg .rbx .bundle)
      other_ignored = %w(bundle vendor/bundle log tmp vendor/ruby)
      (hidden_ignored + other_ignored).each do |dir|
        it { should_not accept(:dir, dir) }
        it { should accept(:dir, "#{dir}foo") }
        it { should accept(:dir, "foo#{dir}") }
      end

      ignored = %w(.DS_Store foo.tmp foo~)

      # Gedit swap files
      ignored += %w(.goutputstream-S3FBGX)

      # Kate editor swap files
      ignored += %w(foo.rbo54321.new foo.rbB22583.new foo.rb.kate-swp)

      # Intellij swap files
      ignored += %w(foo.rb___jb_bak___ foo.rb___jb_old___)

      # Vim swap files
      ignored += %w(foo.swp foo.swx foo.swpx 4913)

      ignored.each do |path|
        it { should_not accept(:file, path) }
      end

      %w(foo.tmpl file.new file54321.new a.swf 14913 49131).each do |path|
        it { should accept(:file, path) }
      end
    end

    context 'when ignoring *.pid' do
      let(:options) { { ignore: /\.pid$/ } }
      it { should_not accept(:file, 'foo.pid') }
    end

    context 'when ignoring foo/bar* and *.pid' do
      let(:options) { { ignore: [%r{^foo/bar}, /\.pid$/] } }
      it { should_not accept(:file, 'foo/bar/baz') }
      it { should_not accept(:file, 'foo.pid') }
    end

    context 'when ignoring only *.pid' do
      let(:options) { { ignore!: /\.pid$/ } }
      it { should_not accept(:file, 'foo.pid') }
      it { should accept(:file, '.git') }
    end

    context 'when accepting only *foo*' do
      let(:options) { { only: %r{foo} } }
      it { should accept(:file, 'foo') }
      it { should_not accept(:file, 'bar') }
    end

    context 'when accepting only foo/* and *.txt' do
      let(:options) { { only: [%r{^foo/}, %r{\.txt$}] } }
      it { should accept(:file, 'foo/bar.rb') }
      it { should accept(:file, 'bar.txt') }
      it { should_not accept(:file, 'bar/baz.rb') }
      it { should_not accept(:file, 'bar.rb') }
    end

    context 'when accepting only *.pid' do
      context 'when ignoring bar*' do
        let(:options) { { only: /\.pid$/, ignore: %r{^bar} } }
        it { should_not accept(:file, 'foo.rb') }
        it { should_not accept(:file, 'bar.pid') }
        it { should accept(:file, 'foo.pid') }
      end
    end
  end
end
