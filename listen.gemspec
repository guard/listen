# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'listen/version'

Gem::Specification.new do |gem| # rubocop:disable Metrics/BlockLength
  gem.name        = 'listen'
  gem.version     = Listen::VERSION
  gem.license     = 'MIT'
  gem.author      = 'Thibaud Guillaume-Gentil'
  gem.email       = 'thibaud@thibaud.gg'
  gem.homepage    = 'https://github.com/guard/listen'
  gem.summary     = 'Listen to file modifications'
  gem.description = 'The Listen gem listens to file modifications and '\
    'notifies you about the changes. Works everywhere!'
  gem.metadata = {
    'allowed_push_host' => 'https://rubygems.org',
    'bug_tracker_uri' => "#{gem.homepage}/issues",
    'changelog_uri' => "#{gem.homepage}/releases",
    'documentation_uri' => "https://www.rubydoc.info/gems/listen/#{gem.version}",
    'homepage_uri' => gem.homepage,
    'source_code_uri' => "#{gem.homepage}/tree/v#{gem.version}"
  }

  gem.files = `git ls-files -z`.split("\x0").select do |f|
    %r{^(?:bin|lib)/} =~ f
  end + %w[CHANGELOG.md CONTRIBUTING.md LICENSE.txt README.md]

  gem.test_files   = []
  gem.executable   = 'listen'
  gem.require_path = 'lib'

  gem.required_ruby_version = '>= 2.4.0' # rubocop:disable Gemspec/RequiredRubyVersion

  gem.add_dependency 'rb-fsevent', '~> 0.10', '>= 0.10.3'
  gem.add_dependency 'rb-inotify', '~> 0.9', '>= 0.9.10'
end
