require 'tmpdir'

include FileUtils

# Prepares the temporary fixture directory and
# cleans it afterwards.
#
# @yield [path] an empty fixture directory
# @yieldparam [String] path the path to the fixture directory
#
def fixtures
  path = File.expand_path(File.join(Dir.tmpdir, 'listen'))
  FileUtils.mkdir_p(path)

  pwd = FileUtils.pwd
  FileUtils.cd(path)

  yield(path)

ensure
  FileUtils.cd pwd
  FileUtils.rm_rf(path) if File.exists?(path)
end

# Start the listener
#
# @param [String] path the path to watch
# @param [Hash] options the listener options
# @yield The block to listen for file changes
# @return [Array, Array, Array] the file changes
#
def listen(path, options={})
  modified = []
  added    = []
  removed  = []

  Listen.to(path, options) do |m, a, r|
    modified += m
    added    += a
    removed  += r
  end

  yield

  [modified, added, removed]
end
