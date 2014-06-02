{
  modification: :modified,
  addition: :added,
  removal: :removed,
  queued_modification: :modified,
  queued_addition: :added,
}.each do |description, type|

  RSpec::Matchers.define "process_#{description}_of".to_sym do |expected|
    match do |actual|
      # Use cases:
      # 1. reset the changes so they don't have leftovers
      # 2. keep the queue if we're testing for existing accumulated changes

      # if were testing the queue (e.g. after unpause), don't reset
      check_already_queued = /queued_/ =~ description
      reset_queue = !check_already_queued

      actual.listen(reset_queue) do
        change_fs(type, expected) unless check_already_queued
      end
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

    # wait until full second, because this might be followed by a modification
    # event (which otherwise may not be detected every time)
    _sleep_until_next_second(Pathname.pwd)

    open(path, 'a') { |f| f.write('foo') }

    # separate it from upcoming modifications"
    _sleep_to_separate_events
  when :added
    if File.exist?(path)
      fail "Bad test: cannot add #{path.inspect} (it already exists)"
    end

    # wait until full second, because this might be followed by a modification
    # event (which otherwise may not be detected every time)
    _sleep_until_next_second(Pathname.pwd)

    open(path, 'w') { |f| f.write('foo') }

    # separate it from upcoming modifications"
    _sleep_to_separate_events
  when :removed
    unless File.exist?(path)
      fail "Bad test: cannot remove #{path.inspect} (it doesn't exist)"
    end
    File.unlink(path)
  else
    fail "bad test: unknown type: #{type.inspect}"
  end
end

# Used by change_fs() above so that the FS change (e.g. file created) happens
# as close to the start of a new second (time) as possible.
#
# E.g. if file is created at 1234567.999 (unix time), it's mtime on some
# filesystems is rounded, so it becomes 1234567.0, but if the change
# notification happens a little while later, e.g. at 1234568.111, now the file
# mtime and the current time in seconds are different (1234567 vs 1234568), and
# so the MD5 test won't kick in (see file.rb) - the file will not be considered
# for content checking (md5), so File.change will consider the file unmodified.
#
# This means, that if a file is added at 1234567.888 (and updated in Record),
# and then its content is modified at 1234567.999, and checking for changes
# happens at 1234568.111, the modification won't be detected.
# (because Record mtime is 1234567.0, current FS mtime from stat() is the
# same, and the checking happens in another second - 1234568).
#
# So basically, adding a file and detecting its later modification should all
# happen within 1 second (which makes testing and debugging difficult).
#
def _sleep_until_next_second(path)
  Listen::File.inaccurate_mac_time?(path)

  t = Time.now
  diff = t.to_f - t.to_i

  sleep(1.05 - diff)
end

# Special class to only allow changes within a specific time window

class TimedChanges
  attr_reader :changes

  def initialize
    # Set to non-nil, because changes can immediately come after unpausing
    # listener in an Rspec 'before()' block
    @changes = { modified: [], added: [], removed: [] }
  end

  def change_offset
    Time.now.to_f - @yield_time
  end

  def freeze_offset
    result = @freeze_time - @yield_time
    # Make an "almost zero" value more readable
    result < 1e-4 ? 1e-4 : result
  end

  # Allow changes only during specific time wine
  def allow_changes(reset_queue = true)
    @freeze_time = nil
    if reset_queue
      # Clear to prepare for collecting new FS events
      @changes = { modified: [], added: [], removed: [] }
    else
      # Since we're testing the queue and the listener callback is adding
      # changes to the same hash (e.g. after a pause), copy the existing data
      # to a new, unfrozen hash
      @changes = @changes.dup if @changes.frozen?
      @changes ||= { modified: [], added: [], removed: [] }
    end

    @yield_time = Time.now.to_f
    yield
    # Prevent recording changes after timeout
    @changes.freeze
    @freeze_time = Time.now.to_f
  end
end

# Conveniently wrap a Listener instance for testing
class ListenerWrapper
  attr_reader :listener, :changes
  attr_accessor :lag

  def initialize(callback, paths, *args)
    # Lag depends mostly on wait_for_delay On Linux desktop, it's 0.06 - 0.11
    #
    # On Travis it used to be > 0.5, but that was before broadcaster sent
    # changes immediately, so 0.2-0.4 might be enough for Travis, but we set it
    # to 0.6
    #
    # The value should be 2-3 x wait_for_delay + time between fs operation and
    # notification, which for polling and FSEvent means the configured latency
    @lag = 0.6

    @paths = paths

    # Isolate collected changes between tests/listener instances
    @timed_changes = TimedChanges.new

    if callback
      @listener = Listen.send(*args) do  |modified, added, removed|
        # Add changes to trigger frozen Hash error, making sure lag is enough
        _add_changes(:modified, modified, changes)
        _add_changes(:added, added, changes)
        _add_changes(:removed, removed, changes)

        unless callback == :track_changes
          callback.call(modified, added, removed)
        end
      end
    else
      @listener = Listen.send(*args)
    end
  end

  def changes
    @timed_changes.changes
  end

  def listen(reset_queue = true)
    # Give previous events time to be received, queued and processed
    # so they complete and don't interfere
    sleep lag

    @timed_changes.allow_changes(reset_queue) do

      yield

      # Polling sleep (default: 1s)
      adapter = @listener.sync(:adapter)
      if adapter.is_a?(Listen::Adapter::Polling)
        sleep adapter.options.latency
      end

      # Lag should include:
      #  0.1s - 0.2s if the test needs Listener queue to be processed
      #  0.1s in case the system is busy
      #  0.1s - for celluloid overhead and scheduling
      sleep lag
    end

    # Keep this to detect a lag too small (changes during this sleep
    # will trigger "frozen hash" error caught below (and displaying timeout
    # details)
    sleep 1

    changes
  end

  private

  def _add_changes(type, changes, dst)
    dst[type] += _relative_path(changes)
    dst[type].uniq!
    dst[type].sort!

  rescue RuntimeError => e
    raise unless e.message == "can't modify frozen Hash"

    # Show how by much the changes missed the timeout
    change_offset = @timed_changes.change_offset
    freeze_offset = @timed_changes.freeze_offset

    msg = "Changes took #{change_offset}s (allowed lag: #{freeze_offset})s"

    # Use STDERR (workaround for Celluloid, since it catches abort)
    STDERR.puts msg
    abort(msg)
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
end

def setup_listener(options, callback = nil)
  ListenerWrapper.new(callback, paths, :to, paths, options)
end

def setup_recipient(port, callback = nil)
  ListenerWrapper.new(callback, paths, :on, port)
end

def _sleep_to_separate_events
  # separate the events or Darwin and Polling
  # will detect only the :added event
  #
  # (This is because both use directory scanning
  # through Celluloid tasks, which may not kick in
  # time before the next filesystem change)
  #
  # The minimum for this is the time it takes between a syscall
  # changing the filesystem ... and ... an async
  # Listen::File.scan to finish comparing the file with the
  # Record
  #
  # This necessary for:
  # - Darwin Adapter
  # - Polling Adapter
  # - Linux Adapter in FSEvent emulation mode
  # - maybe Windows adapter (probably not)
  sleep 0.4
end
