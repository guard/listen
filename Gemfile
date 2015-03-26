source 'https://rubygems.org'

gemspec development_group: :gem_build_tools

require 'rbconfig'

case RbConfig::CONFIG['target_os']
when /mswin|mingw|cygwin/i
  gem 'wdm', '>= 0.1.0'
  Kernel.warn 'NOTE: Celluloid may not work properly on your platform'
when /bsd|dragonfly/i
  gem 'rb-kqueue', '>= 0.2'
end

group :test do
  gem 'celluloid', github: 'celluloid/celluloid', branch: '0-16-stable'
  gem 'celluloid-io', '>= 0.15.0'
  gem 'rake'
  gem 'rspec', '~> 3.0.0rc1'
  gem 'rspec-retry'
  gem 'coveralls'
end

group :development do
  gem 'yard', require: false
  gem 'guard-rspec', require: false
  gem 'rubocop', '0.25.0' # TODO: should match Gemfile HoundCi
  gem 'guard-rubocop'
  gem 'pry-rescue'
  gem 'pry-stack_explorer'
  gem 'gems', require: false
  gem 'netrc', require: false
  gem 'octokit', require: false
end
