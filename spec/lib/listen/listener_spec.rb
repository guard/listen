require 'spec_helper'

describe Listen::Listener do
  let(:listener) { Listen::Listener.new }
  let(:record) { double(Listen::Record, terminate: true, build: true) }
  let(:adapter) { double(Listen::Adapter::Base) }
  let(:change_pool) { double(Listen::Change, terminate: true) }
  let(:change_pool_async) { double('ChangePoolAsync') }
  before {
    Celluloid::Actor.stub(:[]).with(:listen_adapter) { adapter }
    Celluloid::Actor.stub(:[]).with(:listen_record) { record }
    Celluloid::Actor.stub(:[]).with(:listen_change_pool) { change_pool }
  }

  describe "initialize" do
    it "sets paused to false" do
      listener.should_not be_paused
    end

    it "sets block" do
      block = Proc.new { |modified, added, removed| }
      listener = Listen::Listener.new('dir', &block)
      listener.block.should_not be_nil
    end
  end

  describe "options" do
    it "sets default options" do
      listener.options.should eq({
        debug: false,
        latency: nil,
        force_polling: false,
        polling_fallback_message: nil })
    end

    it "sets new options on initialize" do
      listener = Listen::Listener.new('path', latency: 1.234)
      listener.options.should eq({
        debug: false,
        latency: 1.234,
        force_polling: false,
        polling_fallback_message: nil })
    end
  end

  describe "#start" do
    before {
      Listen::Change.stub(:pool)
      Listen::Adapter.stub(:new)
      Listen::Record.stub(:new)
      Celluloid::Actor.stub(:[]=)
      Celluloid.stub(:cores) { 1 }
      adapter.stub_chain(:async, :start)
    }

    it "traps INT signal" do
      expect(Signal).to receive(:trap).with('INT')
      listener.start
    end

    it "registers change_pool" do
      Listen::Change.should_receive(:pool).with(size: 1, args: listener) { change_pool }
      Celluloid::Actor.should_receive(:[]=).with(:listen_change_pool, change_pool)
      listener.start
    end

    it "registers adaper" do
      Listen::Adapter.should_receive(:new).with(listener) { adapter }
      Celluloid::Actor.should_receive(:[]=).with(:listen_adapter, adapter)
      listener.start
    end

    it "registers record" do
      Listen::Record.should_receive(:new).with(listener) { record }
      Celluloid::Actor.should_receive(:[]=).with(:listen_record, record)
      listener.start
    end

    it "builds record" do
      record.should_receive(:build)
      listener.start
    end

    it "sets paused to false" do
      listener.start
      listener.paused.should be_false
    end

    it "starts adapter asynchronously" do
      async_stub = double
      adapter.should_receive(:async) { async_stub }
      async_stub.should_receive(:start)
      listener.start
    end

    it "starts adapter asynchronously" do
      async_stub = double
      adapter.should_receive(:async) { async_stub }
      async_stub.should_receive(:start)
      listener.start
    end

    it "calls block on changes" do
      listener.changes = [{ modified: 'foo' }]
      block_stub = double('block')
      listener.block = block_stub
      block_stub.should_receive(:call).with(['foo'], [], [])
      listener.start
      sleep 0.01
    end
  end

  describe "#stop" do
    before { Celluloid::Actor.stub(:kill) }

    it "kills adapter" do
      Celluloid::Actor.should_receive(:kill).with(adapter)
      listener.stop
    end

    it "terminates change_pool" do
      change_pool.should_receive(:terminate)
      listener.stop
    end

    it "terminates record" do
      record.should_receive(:terminate)
      listener.stop
    end
  end

  describe "#pause" do
    it "sets paused to true" do
      listener.pause
      listener.paused.should be_true
    end
  end

  describe "#unpause" do
    it "builds record" do
      record.should_receive(:build)
      listener.unpause
    end

    it "sets paused to false" do
      record.stub(:build)
      listener.unpause
      listener.paused.should be_false
    end
  end

  describe "#paused?" do
    it "returns true when paused" do
      listener.paused = true
      listener.should be_paused
    end
    it "returns false when not paused (nil)" do
      listener.paused = nil
      listener.should_not be_paused
    end
    it "returns false when not paused (false)" do
      listener.paused = false
      listener.should_not be_paused
    end
  end

  describe "#paused?" do
    it "returns true when not paused (false)" do
      listener.paused = false
      listener.listen?.should be_true
    end
    it "returns false when not paused (nil)" do
      listener.paused = nil
      listener.listen?.should be_false
    end
    it "returns false when paused" do
      listener.paused = true
      listener.listen?.should be_false
    end
  end

end
