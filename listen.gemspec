# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'listen/version'

Gem::Specification.new do |s|
  s.name        = 'listen'
  s.version     = Listen::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Travis Tilley', 'Yehuda Katz', 'Thibaud Guillaume-Gentil', 'Rémy Coutable', 'Michael Kessler']
  s.email       = ['ttilley@gmail.com', 'wycats@gmail.com', 'thibaud@thibaud.me', 'rymai@rymai.me', 'michi@netzpiraten.ch']
  s.homepage    = 'https://github.com/guard/listen'
  s.summary     = 'Listen to file modifications'
  s.description = 'The Listen gem listens to file modifications and notifies you about the changes.'

  s.required_rubygems_version = '>= 1.3.6'
  s.rubyforge_project = 'listen'

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'guard',       '~> 1.0.0'
  s.add_development_dependency 'rspec',       '~> 2.8.0'
  s.add_development_dependency 'guard-rspec', '~> 0.6.0'
  s.add_development_dependency 'yard'
  s.add_development_dependency 'redcarpet'
  s.add_development_dependency 'pry'

  s.files        = Dir.glob('{lib}/**/*') + %w[CHANGELOG.md LICENSE README.md]
  s.require_path = 'lib'
end
