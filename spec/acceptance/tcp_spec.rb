require 'spec_helper'

describe Listen::TCP do

  let(:port) { 4000 }

  let(:broadcaster) { Listen.to(Dir.pwd, forward_to: port) }
  let(:recipient)  { Listen.on(port) }
  let(:callback) { ->(modified, added, removed) {
    add_changes(:modified, modified)
    add_changes(:added, added)
    add_changes(:removed, removed)
  } }
  let(:paths) { Pathname.new(Dir.pwd) }

  around { |example| fixtures { |path| example.run } }

  before do
    broadcaster.start
  end

  context 'when broadcaster' do
    before do
      broadcaster.block = callback
    end

    it 'still handles local changes' do
      expect(listen {
        touch 'file.rb'
      }).to eq(
        modified: [],
        added:    ['file.rb'],
        removed:  []
      )
    end

    it 'may be paused and unpaused' do
      broadcaster.pause

      expect(listen {
        touch 'file.rb'
      }).to eq(
        modified: [],
        added:    [],
        removed:  []
      )

      broadcaster.unpause

      expect(listen {
        touch 'file.rb'
      }).to eq(
        modified: ['file.rb'],
        added:    [],
        removed:  []
      )
    end

    it 'may be stopped and restarted' do
      broadcaster.stop

      expect(listen {
        touch 'file.rb'
      }).to eq(
        modified: [],
        added:    [],
        removed:  []
      )

      broadcaster.start

      expect(listen {
        touch 'file.rb'
      }).to eq(
        modified: ['file.rb'],
        added:    [],
        removed:  []
      )
    end
  end

  context 'when recipient' do
    before do
      recipient.start
      recipient.block = callback
    end

    it 'receives changes over TCP' do
      expect(listen(1) {
        touch 'file.rb'
      }).to eq(
        modified: [],
        added:    ['file.rb'],
        removed:  []
      )
    end

    it 'may be paused and unpaused' do
      recipient.pause

      expect(listen(1) {
        touch 'file.rb'
      }).to eq(
        modified: [],
        added:    [],
        removed:  []
      )

      recipient.unpause

      expect(listen(1) {
        touch 'file.rb'
      }).to eq(
        modified: ['file.rb'],
        added:    [],
        removed:  []
      )
    end

    it 'may be stopped and restarted' do
      recipient.stop

      expect(listen(1) {
        touch 'file.rb'
      }).to eq(
        modified: [],
        added:    [],
        removed:  []
      )

      recipient.start

      expect(listen(1) {
        touch 'file.rb'
      }).to eq(
        modified: ['file.rb'],
        added:    [],
        removed:  []
      )
    end
  end

end
