# Directory changes diff
#
# @param [String] path the path to watch
# @return [Array, Array, Array] the file changes
#
def diff(root_path, options = {})
  modified = []
  added    = []
  removed  = []

  unless @listener
    @listener = Listen::Listener.new(root_path)
    @listener.init_paths
  end

  yield

  paths = options.delete(:paths) || [root_path]
  options[:recursive] = true if options[:recursive].nil?
  changes = @listener.diff(paths, options)
  modified += changes[:modified]
  added    += changes[:added]
  removed  += changes[:removed]

  [modified, added, removed]
end

def new(path, *args)
  Listen::Listener.new(path, *args)
end

def ensure_same_second
  t = Time.now
  if t.to_f - t.to_i > 0.1
    sleep 1.1 - (t.to_f - t.to_i)
  end
end