# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :acceptance, optional: true do
  gem 'capybara', '~> 3.0'
  gem 'selenium-webdriver', '~> 4.0'
  gem 'test-unit', '~> 3.0'
end

group :release, optional: true do
  gem 'faraday-retry', '~> 2.1', require: false
  gem 'github_changelog_generator', '~> 1.16.4', require: false
end
