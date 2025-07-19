# frozen_string_literal: true

require File.expand_path('lib/foreman_bolt/version', __dir__)

Gem::Specification.new do |s|
  s.name        = 'foreman_bolt'
  s.version     = ForemanBolt::VERSION
  s.metadata    = { 'is_foreman_plugin' => 'true' }
  s.license     = 'GPL-3.0'
  s.authors     = ['Overlook InfraTech']
  s.email       = ['contact@overlookinfratech.com']
  s.homepage    = 'https://github.com/overlookinfra/foreman_bolt'
  s.summary     = 'Foreman Bolt integration'
  # also update locale/gemspec.rb
  s.description = 'This plugin adds Bolt integration into Foreman, ' +
                  'allowing users to run tasks and plans present in their environment.'

  s.files = Dir['{app,config,db,lib,locale,webpack}/**/*'] + ['LICENSE', 'Rakefile', 'README.md', 'package.json']
  s.test_files = Dir['test/**/*'] + Dir['webpack/**/__tests__/*.js']

  s.required_ruby_version = '>= 2.7', '< 4'

  s.add_development_dependency 'erb_lint'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc'
end
