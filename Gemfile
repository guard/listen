source 'https://rubygems.org'

gemspec

require 'rbconfig'
gem 'wdm', '>= 0.1.0' if RbConfig::CONFIG['target_os'] =~ /mswin|mingw|cygwin/i

if RbConfig::CONFIG['target_os'] =~ /bsd|dragonfly/i
  gem 'rb-kqueue', '>= 0.2'
  # Versions not included have known bugs
  # Even master branches may not work...
  gem 'ffi', github: 'carpetsmoker/ffi', ref: 'ac63e07f7'
  gem 'celluloid', github: 'celluloid/celluloid', ref: '7fdef04'
end

group :tool do
  gem 'yard', require: false
  gem 'guard-rspec', require: false
  gem 'guard-rubocop'
end

group :test do
  gem 'coveralls', require: false
end
