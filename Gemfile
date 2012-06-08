source :rubygems

gemspec

gem 'rake'

group :development do
  platform :ruby do
    gem 'rb-readline'
  end

  require 'rbconfig'
  case RbConfig::CONFIG['target_os']
  when /darwin/i
    # gem 'ruby_gntp',  '~> 0.3.4', :require => false
    gem 'growl', :require => false
  when /linux/i
    gem 'libnotify',  '~> 0.7.1', :require => false
  when /mswin|mingw/i
    gem 'win32console', :require => false
    gem 'rb-notifu', '>= 0.0.4', :require => false
  end

  gem 'guard',       '~> 1.0.0'
  gem 'guard-rspec', '~> 0.7.0'
  gem 'yard'
  gem 'redcarpet'
  gem 'pry'

  gem 'vagrant'
end

group :test do
  gem 'rspec', '~> 2.10.0'
end