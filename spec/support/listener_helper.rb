# Directory changes diff
#
# @param [String] path the path to watch
# @return [Array, Array, Array] the file changes
#
def diff(path)
  modified = []
  added    = []
  removed  = []

  listener = Listen::Listener.new(path)
  listener.init_paths
  
  yield

  changes = listener.diff
  modified += changes[:modified]
  added    += changes[:added]
  removed  += changes[:removed]

  [modified, added, removed]
end

def new(path, *args)
  Listen::Listener.new(path, *args)
end
