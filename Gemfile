# frozen_string_literal: true

source 'https://rubygems.org'

# Create this file to use pristine/installed version of Listen for development
use_installed = "./use_installed_guard"
if File.exist?(use_installed)
  STDERR.puts "WARNING: using installed version of Listen for development" \
    " (remove #{use_installed} file to use local version)"
else
  gemspec development_group: :gem_build_tools
end

gem 'rb-kqueue', '>= 0.2'
gem 'wdm', '>= 0.1.0'

group :test do
  gem 'coveralls'
  gem 'rake'
  gem 'rspec', '~> 3.3'
end

group :development do
  gem 'bundler'
  gem 'gems', require: false
  gem 'guard-rspec', require: false
  gem 'guard-rubocop'
  gem 'netrc', require: false
  gem 'octokit', require: false
  gem 'pry-rescue'
  gem 'rubocop', require: false
  gem 'yard', require: false
end
