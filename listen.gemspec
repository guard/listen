# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'listen/version'

Gem::Specification.new do |s|
  s.name        = 'listen'
  s.version     = Listen::VERSION
  s.license     = 'MIT'
  s.author      = 'Thibaud Guillaume-Gentil'
  s.email       = 'thibaud@thibaud.gg'
  s.homepage    = 'https://github.com/guard/listen'
  s.summary     = 'Listen to file modifications'
  s.description = 'The Listen gem listens to file modifications and '\
    'notifies you about the changes. Works everywhere!'

  s.files = `git ls-files -z`.split("\x0").select do |f|
    %r{^(?:bin|lib)\/} =~ f
  end + %w(CHANGELOG.md CONTRIBUTING.md LICENSE.txt README.md)

  s.test_files   = []
  s.executable   = 'listen'
  s.require_path = 'lib'

  begin
    # TODO: should this be vendored instead?
    require 'ruby_dep/travis'
    s.required_ruby_version = RubyDep::Travis.new.version_constraint
  rescue LoadError
    abort "Install 'ruby_dep' gem before building this gem"
  end

  s.add_dependency 'rb-fsevent', '~> 0.9', '>= 0.9.4'
  s.add_dependency 'rb-inotify', '~> 0.9', '>= 0.9.7'

  # Used to show warnings at runtime
  s.add_dependency 'ruby_dep', '~> 1.2'

  s.add_development_dependency 'bundler', '~> 1.12'
end
