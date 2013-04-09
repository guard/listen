source 'https://rubygems.org'
gemspec

gem 'rake'

require 'rbconfig'
gem 'rb-kqueue', '~> 0.2' if RbConfig::CONFIG['target_os'] =~ /freebsd/i
gem 'rb-fsevent', '~> 0.9.1' if RbConfig::CONFIG['target_os'] =~ /darwin(1.+)?$/i
gem 'rb-inotify', '~> 0.9.0' if RbConfig::CONFIG['target_os'] =~ /linux/i
gem 'wdm',        '~> 0.0.3' if RbConfig::CONFIG['target_os'] =~ /mswin|mingw/i

group :development do
  gem 'ruby_gntp'
  gem 'guard-rspec'
  gem 'yard'
  gem 'redcarpet'
  gem 'pimpmychangelog'
end

group :test do
  gem 'rspec'
  gem 'coveralls', require: false
end
