require 'listen/thread'

RSpec.describe Listen::Thread do
  let(:name) { "worker_thread" }
  let(:block) { -> { } }
  subject { described_class.new(name, &block) }

  it "calls Thread.new" do
    expect(Thread).to receive(:new) do
      thread = instance_double(Thread, "thread")
      expect(thread).to receive(:name=).with("listen-#{name}")
      thread
    end
    subject
  end

  context "when exception raised" do
    let(:block) do
      -> { raise ArgumentError, 'boom!' }
    end

    it "rescues and logs exceptions" do
      expect(Listen::Logger).to receive(:error)
        .with(/Exception rescued in listen-worker_thread:\nArgumentError: boom!\n.*\/listen\/thread_spec\.rb/)
      subject.join
    end

    it "rescues and logs backtrace + exception backtrace" do
      expect(Listen::Logger).to receive(:error)
        .with(/Exception rescued in listen-worker_thread:\nArgumentError: boom!\n.*\/listen\/thread\.rb.*--- Thread.new ---.*\/listen\/thread_spec\.rb/m)
      subject.join
    end
  end

  context "when nested exceptions raised" do
    let(:block) do
      -> do
        begin
          raise ArgumentError, 'boom!'
        rescue
          raise 'nested inner'
        end
      rescue
        raise 'nested outer'
      end
    end

    it "details exception causes" do
      expect(Listen::Logger).to receive(:error)
        .with(/RuntimeError: nested outer\n--- Caused by: ---\nRuntimeError: nested inner\n--- Caused by: ---\nArgumentError: boom!/)
      subject.join
    end
  end
end
