source 'https://rubygems.org'

gemspec

gem 'rake'

require 'rbconfig'
gem 'wdm', '>= 0.1.0' if RbConfig::CONFIG['target_os'] =~ /mswin|mingw/i

group :development do
  gem 'guard-rspec',     require: false
  gem 'yard',            require: false
  gem 'redcarpet',       require: false
  gem 'pimpmychangelog', require: false
end

group :test do
  gem 'rspec'
  gem 'coveralls', require: false
end
