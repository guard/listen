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
  end

  context 'when recipient' do
    before do
      recipient.start
      recipient.block = callback
    end

    it 'receives changes over TCP' do
      expect(listen {
        touch 'file.rb'
      }).to eq(
        modified: [],
        added:    ['file.rb'],
        removed:  []
      )
    end
  end

end
