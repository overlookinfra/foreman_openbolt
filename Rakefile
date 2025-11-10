# frozen_string_literal: true

# !/usr/bin/env rake

begin
  require 'rdoc/task'
rescue LoadError
  require 'rdoc/rdoc'
  require 'rake/rdoctask'
  RDoc::Task = Rake::RDocTask
end

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'ForemanOpenbolt'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
  puts 'Rubocop not loaded.'
end

# This is all kinda screwy. Fix it up later.
LINTERS = {
  ruby: { cmd: 'rubocop', fix: '--auto-correct' },
  erb: { cmd: 'erb_lint', fix: '--autocorrect', glob: '**/*.erb' },
  js: { image: 'registry.access.redhat.com/ubi9/nodejs-20:latest', cmd: 'npm run lint --', fix: '--fix' },
}.freeze

namespace :lint do
  def fix?
    !ENV['FIX'].nil?
  end

  def local?
    !ENV['LOCAL'].nil?
  end

  def bin
    ENV['CONTAINER_BIN'] || 'docker'
  end

  LINTERS.each do |name, cfg|
    desc "Run #{name} linter#{' (fix)' if fix?}"
    task name do
      cmd = [cfg[:cmd]]
      cmd << cfg[:fix] if fix?
      cmd << cfg[:glob] unless cfg[:glob].nil? || cfg[:glob].empty? # rubocop:disable Rails/Blank
      cmd = cmd.join(' ')
      if cfg[:image] && !local?
        cmd = "#{bin} run --rm -v #{Dir.pwd}:/code #{cfg[:image]} /bin/bash -c " +
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
