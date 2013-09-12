def listen
  sleep 0.25 # wait for changes
  sleep_until_next_second
  reset_changes
  yield
  sleep 0.25 # wait for changes
  @changes
end

def setup_listener(options, callback)
  reset_changes
  Listen.to(paths, options, &callback)
end

def add_changes(type, changes)
  @changes[type] += relative_path(changes)
  @changes[type].sort!
end

def relative_path(changes)
  changes.map do |change|
    [paths].flatten.each { |path| change.gsub!(%r{#{path.to_s}/}, '') }
    change
  end
end

def reset_changes
  @changes = { modified: [], added: [], removed: [] }
end
