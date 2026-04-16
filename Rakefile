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

task default: :lint
