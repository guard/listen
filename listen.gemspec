# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'listen/version'

require 'yaml'

def ruby_version_constraint(filename = '.travis.yml')
  yaml = YAML.load(IO.read(filename))
  failable = yaml['matrix']['allow_failures'].map(&:values).flatten
  versions = yaml['rvm'] - failable

  by_major = versions.map do |x|
    Gem::Version.new(x).segments[0..2]
  end.group_by(&:first)

  last_supported_major = by_major.keys.sort.last
  selected = by_major[last_supported_major].sort.reverse

  lowest = selected.shift
  current = lowest[1]
  while( lower = selected.shift)
    (current -= 1) == lower[1] ? lowest = lower : break
  end

  ["~> #{lowest[0..1].join('.')}", ">= #{lowest.join('.')}"]
end

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

  s.required_ruby_version = ruby_version_constraint

  s.add_dependency 'rb-fsevent', '>= 0.9.3'
  s.add_dependency 'rb-inotify', '>= 0.9.7'

  s.add_development_dependency 'bundler', '>= 1.3.5'
end
