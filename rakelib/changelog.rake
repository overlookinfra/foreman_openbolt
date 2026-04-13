# frozen_string_literal: true

require_relative 'utils/shell'

begin
  require 'rubygems'
  require 'github_changelog_generator/task'

  GitHubChangelogGenerator::RakeTask.new :changelog do |config|
    config.exclude_labels = %w[duplicate question invalid wontfix wont-fix skip-changelog github_actions]
    config.user = 'overlookinfra'
    config.project = 'foreman_openbolt'
    config.future_release = Gem::Specification.load('foreman_openbolt.gemspec').version
  end
rescue LoadError
  task :changelog do
    abort 'Run `bundle install --with release` to install the `github_changelog_generator` gem.'.red
  end
end
