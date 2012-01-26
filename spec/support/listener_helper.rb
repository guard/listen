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

  yield

  changes = listener.diff
  modified += changes[:modified]
  added    += changes[:added]
  removed  += changes[:removed]

  [modified, added, removed]
end
