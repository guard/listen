source :rubygems

gemspec

gem 'rake'

gem 'rb-fsevent', '~> 0.9.1' if RUBY_PLATFORM =~ /darwin(1.+)?$/i
gem 'rb-inotify', '~> 0.8.8' if RUBY_PLATFORM =~ /linux/i
gem 'wdm',        '~> 0.0.2' if RUBY_PLATFORM =~ /mswin|mingw/i

group :development do
  platform :ruby do
    gem 'coolline'
  end

  gem 'guard'
  gem 'guard-rspec'
  gem 'yard'
  gem 'redcarpet'
  gem 'pry'

  gem 'vagrant'
end

group :test do
  gem 'rspec'
end
