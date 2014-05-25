{
  modified: :modification,
  added: :addition,
  removed: :removal
}.each do |type, description|

  RSpec::Matchers.define "detect_#{description}_of".to_sym do |expected|
    match do |actual|
      actual.listen { change_fs(type, expected) }
      actual.changes[type].include? expected
    end

    failure_message do |actual|
      result = actual.changes.inspect
      "expected #{result} to include #{description} of #{expected}"
    end

    failure_message_when_negated do |actual|
      result = actual.changes.inspect
      "expected #{result} to not include #{description} of #{expected}"
    end
  end
end

def change_fs(type, path)
  case type
  when :modified
    unless File.exist?(path)
      fail "Bad test: cannot modify #{path.inspect} (it doesn't exist)"
    end
    open(path, 'a') { |f| f.write('foo') }
  when :added
    if File.exist?(path)
      fail "Bad test: cannot add #{path.inspect} (it already exists)"
    end
    open(path, 'w') { |f| f.write('foo') }
  when :removed
    unless File.exist?(path)
      fail "Bad test: cannot remove #{path.inspect} (it doesn't exist)"
    end
    File.unlink(path)
  else
    fail "bad test: unknown type: #{type.inspect}"
  end
end

class ListenerWrapper
  attr_reader :listener, :changes
  attr_accessor :lag

  def initialize(callback, paths, *args)
    @lag = 0.6
    @paths = paths
    reset_changes

    if callback
      @listener = Listen.send(*args) do  |modified, added, removed|
        # Add changes to trigger frozen Hash error, making sure lag is enough
        _add_changes(:modified, modified, @changes)
        _add_changes(:added, added, @changes)
        _add_changes(:removed, removed, @changes)
        callback.call(modified, added, removed)
      end
    else
      @listener = Listen.send(*args) do |modified, added, removed|
        _add_changes(:modified, modified, @changes)
        _add_changes(:added, added, @changes)
        _add_changes(:removed, removed, @changes)
      end
    end
  end

  def listen
    sleep lag # wait for changes
    _sleep_until_next_second
    reset_changes
    @yield_time = Time.now.to_f
    yield
    sleep lag # wait for changes
    @changes.freeze
    @freeze_time = Time.now.to_f
    @changes
  end

  def reset_changes
    @changes = { modified: [], added: [], removed: [] }
  end

  private

  def _add_changes(type, changes, dst)
    dst[type] += _relative_path(changes)
    dst[type].uniq!
    dst[type].sort!
  rescue RuntimeError => e
    raise unless e.message == "can't modify frozen Hash"

    change_offset = (Time.now.to_f - @yield_time).inspect.to_s
    freeze_offset = (@freeze_time - @yield_time).inspect

    msg = "Changes took #{change_offset}s (allowed lag: #{freeze_offset})s"
    raise msg
  end

  def _relative_path(changes)
    changes.map do |change|
      unfrozen_copy = change.dup
      [@paths].flatten.each do |path|
        sub = path.sub(/\/$/, '').to_s
        unfrozen_copy.gsub!(/^#{sub}\//, '')
      end
      unfrozen_copy
    end
  end

  # Generates a small time difference before performing a time sensitive
  # task (like comparing mtimes of files).
  #
  # @note Modification time for files only includes the milliseconds on Linux
  #   with MRI > 1.9.2 and platform that support it (OS X 10.8 not included),
  #   that's why we generate a difference that's greater than 1 second.
  #
  def _sleep_until_next_second
    return unless darwin? || windows?

    t = Time.now
    diff = t.to_f - t.to_i

    sleep(1.05 - diff)
  end
end

def setup_listener(options, callback = nil)
  ListenerWrapper.new(callback, paths, :to, paths, options)
end

def setup_recipient(port, callback = nil)
  ListenerWrapper.new(callback, paths, :on, port)
end
