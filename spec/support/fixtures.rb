require 'tmpdir'

include FileUtils

# Prepares the temporary fixture directory and
# cleans it afterwards.
#
# @yield [path] an empty fixture directory
# @yieldparam [String] path the path to the fixture directory
#
def fixtures
  pwd  = FileUtils.pwd
  path = File.expand_path(File.join(pwd, "spec/.fixtures"))

  FileUtils.mkdir_p(path)
  FileUtils.cd(path)

  yield(path)

ensure
  FileUtils.cd pwd
  FileUtils.rm_rf(path) if File.exists?(path)
end
