# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'erb_lint', '~> 0.9.0'
gem 'rake', '~> 13.0', '>= 13.0.6'
gem 'rubocop', '~> 1.86'
gem 'rubocop-capybara', '~> 2.22'
gem 'rubocop-performance', '~> 1.26'
gem 'rubocop-rails', '~> 2.29'
gem 'rubocop-rake', '~> 0.7'

group :acceptance, optional: true do
  gem 'capybara', '~> 3.0'
  gem 'selenium-webdriver', '~> 4.0'
  gem 'test-unit', '~> 3.0'
end

group :release, optional: true do
  gem 'faraday-retry', '~> 2.1', require: false
  gem 'github_changelog_generator', '~> 1.18', require: false
end
