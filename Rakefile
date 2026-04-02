# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end

LINTERS = {
  ruby: { cmd: 'rubocop', fix: '--autocorrect' },
  erb: { cmd: 'erb_lint', fix: '--autocorrect', glob: '**/*.erb' },
  js: { image: 'registry.access.redhat.com/ubi9/nodejs-20:latest', cmd: 'npm run lint --', fix: '--fix' },
}.freeze

namespace :lint do
  LINTERS.each do |name, cfg|
    desc "Run #{name} linter"
    task name do
      parts = [cfg[:cmd]]
      parts << cfg[:fix] if ENV['FIX']
      parts << cfg[:glob] if cfg[:glob]
      cmd = parts.join(' ')

      if cfg[:image] && !ENV['LOCAL']
        container_bin = ENV['CONTAINER_BIN'] || 'docker'
        cmd = "#{container_bin} run --rm -v #{Dir.pwd}:/code #{cfg[:image]} /bin/bash -c " \
              "'cd /code && npm install --loglevel=error && #{cmd}'"
      end

      sh cmd
    end
  end

  desc 'Run all linters'
  task all: LINTERS.keys

  desc 'Run all linters and apply fixes'
  task :fix do
    ENV['FIX'] = 'true'
    Rake::Task['lint:all'].invoke
  end
end

task default: ['lint:all', 'test']

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
