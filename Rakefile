# frozen_string_literal: true

namespace :lint do
  desc 'Run Ruby linter'
  task :ruby do
    args = ENV['FIX'] ? '--autocorrect' : ''
    sh "rubocop #{args}".strip
  end

  desc 'Run ERB linter'
  task :erb do
    args = ENV['FIX'] ? '--autocorrect' : ''
    sh "erb_lint #{args} **/*.erb".strip
  end

  desc 'Run JavaScript linter'
  task :js do
    args = ENV['FIX'] ? '-- --fix' : ''
    if ENV['CONTAINER'] # Because npm is kind of a security nightmare
      bin = ENV['CONTAINER_BIN'] || 'docker'
      puts 'The npm ci command may take a while, be patient!'
      sh "#{bin} run --rm -v #{Dir.pwd}:/code -w /code node:20 sh -c 'npm ci --loglevel=error && npm run lint #{args}'".strip
    else
      sh "npm run lint #{args}".strip
    end
  end
end

desc 'Run all linters'
task lint: ['lint:ruby', 'lint:erb', 'lint:js']

desc 'Run all linters and apply fixes'
task 'lint:fix' do
  ENV['FIX'] = 'true'
  Rake::Task['lint'].invoke
end

task default: ['lint']

begin
  require 'rubygems'
  require 'github_changelog_generator/task'

  GitHubChangelogGenerator::RakeTask.new :changelog do |config|
    config.exclude_labels = %w[duplicate question invalid wontfix wont-fix skip-changelog github_actions]
    config.user = 'overlookinfra'
    config.project = 'foreman_openbolt'
    gem_version = Gem::Specification.load("#{config.project}.gemspec").version
    config.future_release = gem_version
  end
rescue LoadError
  task :changelog do
    abort("Run `bundle install --with release` to install the `github_changelog_generator` gem.")
  end
end
