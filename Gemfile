source 'https://rubygems.org'

# Create this file to use pristine/installed version of Listen for development
use_installed = "./use_installed_guard"
if File.exist?(use_installed)
  STDERR.puts "WARNING: using installed version of Listen for development" \
    " (remove #{use_installed} file to use local version)"
else
  gemspec development_group: :gem_build_tools
end

require 'rbconfig'

case RbConfig::CONFIG['target_os']
when /mswin|mingw|cygwin/i
  gem 'wdm', '>= 0.1.0'
when /bsd|dragonfly/i
  gem 'rb-kqueue', '>= 0.2'
end

group :test do
  gem 'rake'
  gem 'rspec', '~> 3.3'
  gem 'coveralls'
end

group :development do
  gem 'yard', require: false
  gem 'guard-rspec', require: false
  gem 'rubocop', '0.38.0' # TODO: should match Gemfile HoundCi
  gem 'guard-rubocop'
  gem 'pry-rescue'
  gem 'pry-stack_explorer', platforms: [:mri, :rbx]
  gem 'gems', require: false
  gem 'netrc', require: false
  gem 'octokit', require: false
end
