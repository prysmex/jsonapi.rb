require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yaml'

desc('Codestyle check and linter')
RuboCop::RakeTask.new('qa:code') do |task|
  task.fail_on_error = true
  task.patterns = [
    'lib/**/*.rb',
    'spec/**/*.rb'
  ]
end

desc('Run CI QA tasks')
task(qa: ['qa:docs', 'qa:code'])

RSpec::Core::RakeTask.new(spec: :qa)
task(default: :spec)
