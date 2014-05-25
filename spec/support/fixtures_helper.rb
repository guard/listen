require 'tmpdir'

include FileUtils

# Prepares temporary fixture-directories and
# cleans them afterwards.
#
# @param [Fixnum] number_of_directories the number of fixture-directories to
# make
#
# @yield [path1, path2, ...] the empty fixture-directories
# @yieldparam [String] path the path to a fixture directory
#
def fixtures(number_of_directories = 1)
  current_pwd = Dir.pwd
  paths = 1.upto(number_of_directories).map { mk_fixture_tmp_dir }

  FileUtils.cd(paths.first) if number_of_directories == 1

  yield(*paths)
ensure
  FileUtils.cd current_pwd
  paths.map { |p| FileUtils.rm_rf(p) if File.exist?(p) }
end

def mk_fixture_tmp_dir
  timestamp = Time.now.to_f.to_s.sub('.', '') + rand(9999).to_s
  path = Pathname.pwd.join('spec', '.fixtures', timestamp).expand_path
  path.tap(&:mkpath)
end
