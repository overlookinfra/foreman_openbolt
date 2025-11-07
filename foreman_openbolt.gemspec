# frozen_string_literal: true

require File.expand_path('lib/foreman_openbolt/version', __dir__)

Gem::Specification.new do |s|
  s.name        = 'foreman_openbolt'
  s.version     = ForemanOpenbolt::VERSION
  s.metadata    = { 'is_foreman_plugin' => 'true' }
  s.license     = 'GPL-3.0-only'
  s.authors     = ['Overlook InfraTech']
  s.email       = ['contact@overlookinfratech.com']
  s.homepage    = 'https://github.com/overlookinfra/foreman_openbolt'
  s.summary     = 'Foreman OpenBolt integration'
  # also update locale/gemspec.rb
  s.description = 'This plugin adds OpenBolt integration into Foreman, ' +
                  'allowing users to run tasks and plans present in their environment.'

  s.files = Dir['{app,config,db,lib,locale,webpack}/**/*'] + ['LICENSE', 'Rakefile', 'README.md', 'package.json']
  s.test_files = Dir['test/**/*'] + Dir['webpack/**/__tests__/*.js']

  s.required_ruby_version = '>= 2.7', '< 4'

  s.add_dependency 'foreman-tasks', '~> 11.0', '>= 11.0.6'

  s.add_development_dependency 'erb_lint', '~> 0.9.0'
  s.add_development_dependency 'rake', '~> 13.0', '>= 13.0.6'
  s.add_development_dependency 'rdoc', '~> 6.5'
  s.add_development_dependency 'theforeman-rubocop', '~> 0.1.2'
end
