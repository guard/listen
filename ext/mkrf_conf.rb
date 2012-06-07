require 'rubygems'
require 'rubygems/command'
require 'rubygems/dependency_installer'
require 'rbconfig'

begin
  Gem::Command.build_args = ARGV
rescue NoMethodError
end

begin
  dependency = Gem::DependencyInstaller.new
  
  if RbConfig::CONFIG['target_os'] =~ /darwin(1.+)?$/i
    dependency.install 'rb-fsevent', '~> 0.9.1'
  elsif RbConfig::CONFIG['target_os'] =~ /linux/i
    dependency.install 'rb-inotify', '~> 0.8.8'
  elsif RbConfig::CONFIG['target_os'] =~ /mswin|mingw/i
    dependency.install 'rb-fchange', '~> 0.0.5'
  end
rescue
  exit 1
end 
