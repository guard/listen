source 'https://rubygems.org'

gemspec

gem 'rake'

require 'rbconfig'
gem 'wdm', '>= 0.1.0' if RbConfig::CONFIG['target_os'] =~ /mswin|mingw|cygwin/i
gem 'rb-kqueue', '>= 0.2' if RbConfig::CONFIG['target_os'] =~ /freebsd/i

group :development do
  gem 'yard', require: false
  gem 'guard-rspec', require: false
end

group :test do
  gem 'rspec'
  gem 'rspec-retry'
  gem 'coveralls',   require: false
end
