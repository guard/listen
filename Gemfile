source 'https://rubygems.org'

gemspec

require 'rbconfig'

case RbConfig::CONFIG['target_os']

when /mswin|mingw|cygwin/i
  gem 'wdm', '>= 0.1.0'
  Kernel.warn 'NOTE: Known issues for your platform:'
  Kernel.warn ' * celluloid-io dns resovler bug causes TCP adapter to fail'
  Kernel.warn ' (fixed celluloid-io requires unreleased celluloid version)'
  Kernel.warn " * celluloid master branch doesn't work properly on Windows"

  # has fix, but causes above other problems:
  # gem 'celluloid-io', github: 'celluloid/celluloid-io', ref: 'a72cae2e'

when /bsd|dragonfly/i

  gem 'rb-kqueue', '>= 0.2'

  Kernel.warn 'NOTE: BSD is unsupported because:'
  Kernel.warn "* Ruby threads don't work correctly (Ruby/MRI unit tests)"
  Kernel.warn "* and because of them, Celluloid doesn't work correctly"

  Kernel.warn '* FFI blows up when libc is a LD script (ac63e07f7)'
  gem 'ffi', github: 'carpetsmoker/ffi', ref: 'ac63e07f7'

  Kernel.warn '* Celluloid core detection blows up (7fdef04)'
  gem 'celluloid', github: 'celluloid/celluloid', ref: '7fdef04'

else
  # handled by gemspec
end

group :tool do
  gem 'yard', require: false
  gem 'guard-rspec', require: false
  gem 'guard-rubocop'
  gem 'pry-rescue'
  gem 'pry-stack_explorer'
end

group :test do
  gem 'coveralls', require: false
end
