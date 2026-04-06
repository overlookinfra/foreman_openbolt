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

COMPOSE_FILE = File.join(__dir__, 'test', 'docker', 'docker-compose.yml')

def compose(*args)
  return if system('docker', 'compose', '-f', COMPOSE_FILE, *args)
  abort "docker compose #{args.join(' ')} failed (exit #{$?.exitstatus})"
end

# Find the latest semver release tag from the Foreman repo.
# Filters to clean X.Y.Z tags only, ignoring pre-releases and non-version tags.
def latest_foreman_tag
  output = `git ls-remote --tags https://github.com/theforeman/foreman.git`
  abort 'Failed to fetch Foreman tags' unless $?.success?

  tags = output.scan(%r{refs/tags/([^\s]+)$}).flatten
  versions = tags.filter_map do |tag|
    Gem::Version.new(tag)
  rescue ArgumentError
    nil
  end
  versions.reject(&:prerelease?).max&.to_s
end

namespace :test do
  desc 'Detect latest Foreman release tag (set FOREMAN_REF to override)'
  task :detect_foreman_ref do
    if ENV['FOREMAN_REF']
      puts "Using FOREMAN_REF=#{ENV['FOREMAN_REF']}"
    else
      latest = latest_foreman_tag
      abort 'Could not detect Foreman release tags' unless latest
      ENV['FOREMAN_REF'] = latest
      puts "Detected latest Foreman tag: #{latest}"
    end
  end

  desc 'Build the test container image'
  task build: :detect_foreman_ref do
    compose('build', '--build-arg', "FOREMAN_REF=#{ENV['FOREMAN_REF']}", 'test')
  end

  desc 'Start test infrastructure and prepare for testing'
  task up: :build do
    # Start both containers (db + test) and leave them running
    compose('up', '-d')

    # Wire the plugin into Foreman's bundle and install its gems
    compose('exec', 'test', 'sh', '-c',
      "printf \"gem 'foreman_openbolt', path: '/opt/foreman_openbolt'\\n" \
      "gem 'foreman-tasks', '>= 11.0.0', '< 12'\\n\" " \
      '> /opt/foreman/bundler.d/foreman_openbolt.rb')
    compose('exec', 'test', 'bundle', 'install', '--jobs=4')

    # Create database if needed and run migrations
    compose('exec', '-e', 'VERBOSE=false', 'test', 'bundle', 'exec', 'rake', 'db:prepare')

    # Install JS dependencies
    compose('exec', '-w', '/opt/foreman_openbolt', 'test',
      'npm', 'install', '--legacy-peer-deps', '--loglevel=error')

    puts 'Test infrastructure is ready. Run `rake test:all` to execute tests.'
  end

  desc 'Run Ruby unit tests (requires test:up first)'
  task :ruby do
    # This is written a bit manually, rather than relying on Rake::TestTask to
    # do the magic which would require running 'rake test:foreman_openbolt'. Since
    # we have both Ruby and JS tests, this lets us have a bit more control over
    # naming and how it runs.
    test_cmd = "files = Dir.glob('/opt/foreman_openbolt/test/**/*_test.rb'); " \
               "abort('No test files found, check volume mount') if files.empty?; " \
               "files.each { |f| require f }"
    compose('exec', 'test',
      'bundle', 'exec', 'ruby', '-Itest', '-I/opt/foreman_openbolt/test',
      '-e', test_cmd)
  end

  desc 'Run JavaScript unit tests (requires test:up first)'
  task :js do
    compose('exec', '-w', '/opt/foreman_openbolt', 'test',
      './node_modules/.bin/jest')
  end

  desc 'Run all tests (requires test:up first)'
  task all: [:ruby, :js]

  desc 'Stop test containers and clean up'
  task :down do
    compose('down')
  end
end

desc 'Run full test cycle: up, test, down'
task :test do
  Rake::Task['test:up'].invoke
  Rake::Task['test:all'].invoke
ensure
  begin
    Rake::Task['test:down'].invoke
  rescue StandardError => e
    warn "Warning: test:down cleanup failed: #{e.message}"
  end
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
