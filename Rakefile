require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

if ENV["CI"] != "true"
  require "rubocop/rake_task"
  RuboCop::RakeTask.new(:rubocop)
  task default: [:spec, :rubocop]
else
  task default: [:spec]
end
