# frozen_string_literal: true

require_relative 'utils/container'

UNIT_COMPOSE = File.join(__dir__, '..', 'test', 'unit', 'docker', 'docker-compose.yml')
ENV['FOREMAN_BRANCH'] ||= FOREMAN_VERSION == 'develop' ? 'develop' : "#{FOREMAN_VERSION}-stable"

namespace :test do
  namespace :unit do
    desc 'Build the unit test container image'
    task :build do
      Container.compose(UNIT_COMPOSE, 'build', '--build-arg', "FOREMAN_BRANCH=#{ENV['FOREMAN_BRANCH']}", 'test')
    end

    desc 'Start unit test infrastructure and prepare for testing'
    task up: :build do
      Container.compose(UNIT_COMPOSE, 'up', '-d')

      Container.compose(UNIT_COMPOSE, 'exec', 'test', 'sh', '-c',
        "printf \"gem 'foreman_openbolt', path: '/opt/foreman_openbolt'\\n" \
        "gem 'foreman-tasks', '>= 11.0.0', '< 12'\\n\" " \
        '> /opt/foreman/bundler.d/foreman_openbolt.rb')
      Container.compose(UNIT_COMPOSE, 'exec', 'test', 'bundle', 'install', '--jobs=4')
      Container.compose(UNIT_COMPOSE, 'exec', '-e', 'VERBOSE=false', 'test', 'bundle', 'exec', 'rake', 'db:prepare')
      Container.compose(UNIT_COMPOSE, 'exec', '-w', '/opt/foreman_openbolt', 'test',
        'npm', 'install', '--legacy-peer-deps', '--loglevel=error')

      puts 'Test infrastructure is ready. Run `rake test:unit:all` to execute tests.'
    end

    desc 'Run Ruby unit tests (requires test:unit:up first)'
    task :ruby do
      test_cmd = "files = Dir.glob('/opt/foreman_openbolt/test/unit/**/*_test.rb'); " \
                 "abort('No test files found, check volume mount') if files.empty?; " \
                 "files.each { |f| require f }"
      Container.compose(UNIT_COMPOSE, 'exec', 'test',
        'bundle', 'exec', 'ruby', '-Itest', '-I/opt/foreman_openbolt/test',
        '-e', test_cmd)
    end

    desc 'Run JavaScript unit tests (requires test:unit:up first)'
    task :js do
      Container.compose(UNIT_COMPOSE, 'exec', '-e', 'NODE_OPTIONS=--no-deprecation',
        '-w', '/opt/foreman_openbolt', 'test', './node_modules/.bin/jest')
    end

    desc 'Run all unit tests (requires test:unit:up first)'
    task all: [:ruby, :js]

    desc 'Stop unit test containers and clean up'
    task :down do
      Container.compose(UNIT_COMPOSE, 'down')
    end
  end
end

desc 'Run full unit test cycle: up, test, down'
task :test do
  Rake::Task['test:unit:up'].invoke
  Rake::Task['test:unit:all'].invoke
ensure
  begin
    Rake::Task['test:unit:down'].invoke
  rescue StandardError => e
    warn "Warning: test:unit:down cleanup failed: #{e.message}".yellow
  end
end
