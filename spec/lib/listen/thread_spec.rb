# frozen_string_literal: true

require 'listen/thread'

RSpec.describe Listen::Thread do
  let(:raise_nested_exception_block) do
    -> do
      begin
        begin
          raise ArgumentError, 'boom!'
        rescue
          raise 'nested inner'
        end
      rescue
        raise 'nested outer'
      end
    end
  end

  let(:raise_script_error_block) do
    -> do
      raise ScriptError, "ruby typo!"
    end
  end

  describe '.new' do
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
        pattern = <<~EOS.strip
          Exception rescued in listen-worker_thread:
          ArgumentError: boom!
          .*\\/listen\\/thread_spec\\.rb
        EOS
        expect(Listen.logger).to receive(:error).with(/#{pattern}/)
        subject.join
      end

      it "rescues and logs backtrace + exception backtrace" do
        pattern = <<~EOS.strip
          Exception rescued in listen-worker_thread:
          ArgumentError: boom!
          .*\\/listen\\/thread\\.rb.*--- Thread.new ---.*\\/listen\\/thread_spec\\.rb
        EOS
        expect(Listen.logger).to receive(:error).with(/#{pattern}/m)
        subject.join
      end
    end

    class TestExceptionDerivedFromException < Exception; end # rubocop:disable Lint/InheritException

    context "when exception raised that is not derived from StandardError" do
      [SystemExit, SystemStackError, NoMemoryError, SecurityError, TestExceptionDerivedFromException].each do |exception|
        context exception.name do
          let(:block) do
            -> { raise exception, 'boom!' }
          end

          it "does not rescue" do
            expect(Thread).to receive(:new) do |&block|
              expect do
                block.call
              end.to raise_exception(exception, 'boom!')

              thread = instance_double(Thread, "thread")
              allow(thread).to receive(:name=).with(any_args)
              thread
            end

            subject
          end
        end
      end
    end

    context "when nested exceptions raised" do
      let(:block) { raise_nested_exception_block }

      it "details exception causes" do
        pattern = <<~EOS
          RuntimeError: nested outer
          --- Caused by: ---
          RuntimeError: nested inner
          --- Caused by: ---
          ArgumentError: boom!
        EOS
        expect(Listen.logger).to receive(:error).with(/#{pattern}/)
        subject.join
      end
    end
  end

  describe '.rescue_and_log' do
    it 'rescues and logs nested exceptions' do
      pattern = <<~EOS
        Exception rescued in method:
        RuntimeError: nested outer
        --- Caused by: ---
        RuntimeError: nested inner
        --- Caused by: ---
        ArgumentError: boom!
      EOS
      expect(Listen.logger).to receive(:error).with(/#{pattern}/)
      described_class.rescue_and_log("method", &raise_nested_exception_block)
    end

    context 'when exception raised that is not derived from StandardError' do
      let(:block) { raise_script_error_block }

      it "raises out" do
        expect do
          described_class.rescue_and_log("method", &raise_script_error_block)
        end.to raise_exception(ScriptError, "ruby typo!")
      end
    end
  end
end
