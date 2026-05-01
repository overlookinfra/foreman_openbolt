# frozen_string_literal: true

require_relative 'rakelib/utils/shell'

def latest_foreman_version
  result = Shell.capture(
    ['git', 'ls-remote', '--tags', 'https://github.com/theforeman/foreman.git'],
    print_command: false, allowed_exit_codes: [0, 1]
  )
  tags = result.output.scan(%r{refs/tags/([^\s]+)$}).flatten
  versions = tags.filter_map do |tag|
    Gem::Version.new(tag)
  rescue ArgumentError
    nil
  end
  latest = versions.reject(&:prerelease?).max
  latest ? "#{latest.segments[0]}.#{latest.segments[1]}" : '3.18'
end

DEFAULT_FOREMAN_VERSION = latest_foreman_version
FOREMAN_VERSION = ENV.fetch('FOREMAN_VERSION', DEFAULT_FOREMAN_VERSION)

def minimum_supported_foreman_version
  engine_path = File.join(__dir__, 'lib', 'foreman_openbolt', 'engine.rb')
  content = File.read(engine_path)
  match = content.match(/requires_foreman\s+['"]>= (\d+\.\d+)/)
  abort 'Could not parse minimum Foreman version from engine.rb'.red unless match
  match[1]
end

def supported_foreman_releases
  min = Gem::Version.new(minimum_supported_foreman_version)
  max = Gem::Version.new(DEFAULT_FOREMAN_VERSION)

  result = Shell.capture(
    ['git', 'ls-remote', '--tags', 'https://github.com/theforeman/foreman.git'],
    print_command: false, allowed_exit_codes: [0, 1]
  )
  tags = result.output.scan(%r{refs/tags/([^\s]+)$}).flatten
  versions = tags.filter_map do |tag|
    Gem::Version.new(tag)
  rescue ArgumentError
    nil
  end

  versions.reject(&:prerelease?)
          .map { |v| "#{v.segments[0]}.#{v.segments[1]}" }
          .uniq
          .map { |v| Gem::Version.new(v) }
          .grep(min..max)
          .sort
          .map(&:to_s)
end

task default: :lint
