# frozen_string_literal: true

# !/usr/bin/env rake
begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end
begin
  require 'rdoc/task'
rescue LoadError
  require 'rdoc/rdoc'
  require 'rake/rdoctask'
  RDoc::Task = Rake::RDocTask
end

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'ForemanBolt'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

Bundler::GemHelper.install_tasks

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

LINTERS = {
  ruby: { cmd: 'rubocop', fix: '--auto-correct', glob: '' },
  erb: { cmd: 'erb_lint', fix: '--autocorrect', glob: '**/*.erb' },
  js: { cmd: 'npx eslint', fix: '--fix', glob: '**/*.js' },
}.freeze

namespace :lint do
  def fix?
    ENV['FIX'] == 'true'
  end

  LINTERS.each do |name, cfg|
    desc "Run #{name} linter#{' (fix)' if fix?}"
    task name do
      cmd = [cfg[:cmd]]
      cmd << cfg[:fix] if fix?
      cmd << cfg[:glob] unless cfg[:glob].empty?
      sh cmd.join(' ')
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
