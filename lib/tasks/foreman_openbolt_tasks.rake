# frozen_string_literal: true

require 'rake/testtask'

# Tasks
namespace :foreman_openbolt do
  namespace :example do
    desc 'Example Task'
    task task: :environment do
      # Task goes here
    end
  end
end

# Tests
namespace :test do
  desc 'Test ForemanOpenbolt'
  Rake::TestTask.new(:foreman_openbolt) do |t|
    test_dir = File.expand_path('../../test', __dir__)
    t.libs << 'test'
    t.libs << test_dir
    t.pattern = "#{test_dir}/**/*_test.rb"
    t.verbose = true
    t.warning = false
  end
end

Rake::Task[:test].enhance ['test:foreman_openbolt']

load 'tasks/jenkins.rake'
Rake::Task['jenkins:unit'].enhance ['test:foreman_openbolt', 'foreman_openbolt:rubocop'] if Rake::Task.task_defined?(:'jenkins:unit')
