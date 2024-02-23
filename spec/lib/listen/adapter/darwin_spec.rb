# frozen_string_literal: true

# This is just so stubs work
require 'rb-fsevent'

require 'listen/adapter/darwin'

include Listen

RSpec.describe Adapter::Darwin do
  describe 'class' do
    subject { described_class }

    context 'on darwin 13.0 (OS X Mavericks)' do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).and_return('darwin13.0')
      end

      it { should be_usable }
    end

    context 'on darwin20 (macOS Big Sur)' do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).and_return('darwin20')
      end

      it { should be_usable }
    end

    context 'on darwin10.0 (OS X Snow Leopard)' do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).and_return('darwin10.0')
      end

      context 'with rb-fsevent > 0.9.4' do
        before { stub_const('FSEvent::VERSION', '0.9.6') }
        it 'shows a warning and should not be usable' do
          expect(Listen).to receive(:adapter_warn)
          expect(subject).to_not be_usable
        end
      end

      context 'with rb-fsevent <= 0.9.4' do
        before { stub_const('FSEvent::VERSION', '0.9.4') }
        it { should be_usable }
      end
    end

    context 'on another platform (linux)' do
      before { allow(RbConfig::CONFIG).to receive(:[]).and_return('linux') }
      it { should_not be_usable }
    end
  end

  let(:options) { {} }
  let(:config) { instance_double(Listen::Adapter::Config) }
  let(:queue) { instance_double(::Queue) }
  let(:silencer) { instance_double(Listen::Silencer) }

  let(:dir1) { fake_path('/foo/dir1', cleanpath: fake_path('/foo/dir1')) }
  let(:directories) { [dir1] }

  subject { described_class.new(config) }

  before do
    allow(config).to receive(:directories).and_return(directories)
    allow(config).to receive(:adapter_options).and_return(options)
  end

  describe '#_latency' do
    subject { described_class.new(config).options.latency }

    context 'with no overriding option' do
      it { should eq 0.1 }
    end

    context 'with custom latency overriding' do
      let(:options) { { latency: 1234 } }
      it { should eq 1234 }
    end
  end
end
