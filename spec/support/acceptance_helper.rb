def listen(lag = 0.5)
  sleep lag # wait for changes
  sleep_until_next_second
  reset_changes
  yield
  sleep lag # wait for changes
  @changes
end

def setup_listener(options, callback)
  reset_changes
  Listen.to(paths, options, &callback)
end

def reset_changes
  @changes = { modified: [], added: [], removed: [] }
end

def add_changes(type, changes)
  @changes[type] += relative_path(changes)
  @changes[type].uniq!
  @changes[type].sort!
end

def relative_path(changes)
  changes.map do |change|
    [paths].flatten.each { |path| change.gsub!(%r{#{path.to_s}/}, '') }
    change
  end
end

# Generates a small time difference before performing a time sensitive
# task (like comparing mtimes of files).
#
# @note Modification time for files only includes the milliseconds on Linux with MRI > 1.9.2
#   and platform that support it (OS X 10.8 not included),
#   that's why we generate a difference that's greater than 1 second.
#
def sleep_until_next_second
  return unless darwin?

  t = Time.now
  diff = t.to_f - t.to_i

  sleep(1.05 - diff)
end
