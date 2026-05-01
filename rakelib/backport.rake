# frozen_string_literal: true

require 'tmpdir'
require_relative 'utils/shell'

FOREMAN_PACKAGING_UPSTREAM_URL = 'https://github.com/theforeman/foreman-packaging'

def backport_github_username
  return ENV['GITHUB_USER'] if ENV['GITHUB_USER']

  result = Shell.capture(
    ['gh', 'api', 'user', '--jq', '.login'],
    print_command: false, allowed_exit_codes: [0, 1]
  )
  login = result.output.strip
  return login if result.exitcode.zero? && !login.empty?

  abort 'Could not determine GitHub username. Set GITHUB_USER env var or authenticate the gh CLI.'.red
end

def clone_foreman_packaging
  dir = File.join(Dir.tmpdir, 'foreman-packaging-backport')
  gh_user = backport_github_username
  origin_url = "git@github.com:#{gh_user}/foreman-packaging"

  if File.directory?(dir)
    puts 'Updating existing foreman-packaging clone...'.magenta
    Shell.run(['git', '-C', dir, 'remote', 'set-url', 'origin', origin_url])
    Shell.run(['git', '-C', dir, 'fetch', 'upstream'])
  else
    puts 'Cloning foreman-packaging...'.magenta
    Shell.run(['git', 'clone', FOREMAN_PACKAGING_UPSTREAM_URL, dir])
    Shell.run(['git', '-C', dir, 'remote', 'rename', 'origin', 'upstream'])
    Shell.run(['git', '-C', dir, 'remote', 'add', 'origin', origin_url])
  end

  dir
end

def find_bump_commit(dir, branch, package_name)
  result = Shell.capture(
    ['git', '-C', dir, 'log', branch, '-1', '--format=%H %s', '--grep', package_name],
    print_command: false
  )
  line = result.output.strip
  abort "No commit found for '#{package_name}' on #{branch}".red if line.empty?

  sha, message = line.split(' ', 2)
  version_match = message.match(/to (\d+\.\d+\.\d+)/)
  gem_version = version_match ? version_match[1] : 'unknown'

  { sha: sha, message: message, version: gem_version }
end

def gh_available?
  Shell.capture(['which', 'gh'], print_command: false, allowed_exit_codes: [0, 1]).exitcode.zero?
end

def verify_gh_permissions
  return unless gh_available?

  puts 'Checking gh authentication and permissions...'.magenta

  gh_user = backport_github_username
  puts "  GitHub user: #{gh_user}".green

  result = Shell.capture(
    ['gh', 'api', "repos/#{gh_user}/foreman-packaging", '--jq', '.fork'],
    print_command: false, allowed_exit_codes: [0, 1]
  )
  if result.exitcode.zero? && result.output.strip == 'true'
    puts "  Fork #{gh_user}/foreman-packaging exists".green
  else
    abort "Fork #{gh_user}/foreman-packaging not found. Fork theforeman/foreman-packaging first.".red
  end

  result = Shell.capture(
    ['gh', 'api', "repos/#{gh_user}/foreman-packaging", '--jq', '.permissions.push'],
    print_command: false, allowed_exit_codes: [0, 1]
  )
  unless result.exitcode.zero? && result.output.strip == 'true'
    abort "gh token does not have push access to #{gh_user}/foreman-packaging.".red
  end
  puts '  Push access to fork confirmed'.green

  result = Shell.capture(
    ['gh', 'api', "orgs/theforeman/memberships/#{gh_user}", '--jq', '.state'],
    print_command: false, allowed_exit_codes: [0, 1]
  )
  unless result.exitcode.zero? && result.output.strip == 'active'
    abort "gh token cannot read org membership for theforeman. Ensure the token has 'read:org' permission.".red
  end
  puts '  Org membership access confirmed'.green

  result = Shell.capture(
    ['gh', 'api', 'repos/theforeman/foreman-packaging', '--jq', '.permissions.push'],
    print_command: false, allowed_exit_codes: [0, 1]
  )
  if result.exitcode.zero? && result.output.strip == 'true'
    puts '  PR creation access confirmed'.green
  else
    abort 'gh token lacks push access to theforeman/foreman-packaging, which is required to create PRs.'.red
  end
end

def backport_to_branches(dir, branch_prefix:, timestamp:, pr_urls:)
  develop_ref = "upstream/#{branch_prefix}/develop"

  smart_proxy_pkg, foreman_pkg = if branch_prefix == 'rpm'
                                   ['rubygem-smart_proxy_openbolt', 'rubygem-foreman_openbolt']
                                 else
                                   ['ruby-smart-proxy-openbolt', 'ruby-foreman-openbolt']
                                 end

  puts "\nLooking for package bump commits on #{develop_ref}...".magenta

  smart_proxy_commit = find_bump_commit(dir, develop_ref, smart_proxy_pkg)
  puts "  #{smart_proxy_pkg}: #{smart_proxy_commit[:sha][0..7]} (#{smart_proxy_commit[:version]})".green

  foreman_commit = find_bump_commit(dir, develop_ref, foreman_pkg)
  puts "  #{foreman_pkg}: #{foreman_commit[:sha][0..7]} (#{foreman_commit[:version]})".green

  versions = supported_foreman_releases
  use_gh = gh_available?
  gh_user = use_gh ? backport_github_username : nil

  versions.each do |version|
    target_ref = "upstream/#{branch_prefix}/#{version}"
    branch_name = "cherry-pick/openbolt_#{branch_prefix}-#{version}_#{timestamp}"

    puts "\nBackporting to #{branch_prefix}/#{version}...".magenta

    Shell.run(['git', '-C', dir, 'checkout', '--force', target_ref], print_command: false)
    Shell.run(['git', '-C', dir, 'clean', '-fd'], print_command: false)
    Shell.run(['git', '-C', dir, 'checkout', '-b', branch_name])
    Shell.run(['git', '-C', dir, 'cherry-pick', smart_proxy_commit[:sha]])
    Shell.run(['git', '-C', dir, 'cherry-pick', foreman_commit[:sha]])
    Shell.run(['git', '-C', dir, 'push', 'origin', branch_name])
    puts "  Pushed #{branch_name}".green

    next unless use_gh

    pr_title = "Cherry pick smart_proxy_openbolt #{smart_proxy_commit[:version]} " \
               "and foreman_openbolt #{foreman_commit[:version]} " \
               "to #{branch_prefix}/#{version}"
    result = Shell.capture(
      ['gh', 'pr', 'create',
       '--repo', 'theforeman/foreman-packaging',
       '--base', "#{branch_prefix}/#{version}",
       '--head', "#{gh_user}:#{branch_name}",
       '--title', pr_title,
       '--body', ''],
      allowed_exit_codes: [0, 1]
    )
    if result.exitcode.zero?
      pr_urls << result.output.strip
      puts "  PR created for #{branch_prefix}/#{version}".green
    else
      puts "  PR creation failed for #{branch_prefix}/#{version}".yellow
    end
  end
end

desc 'Cherry-pick OpenBolt package bumps to all supported Foreman release branches in foreman-packaging'
task :backport do
  verify_gh_permissions
  dir = clone_foreman_packaging
  timestamp = Time.now.utc.strftime('%Y-%m-%d_%H-%M-%S')
  versions = supported_foreman_releases

  puts "Supported Foreman releases: #{versions.join(', ')}".magenta
  puts "Backport timestamp: #{timestamp}".magenta

  pr_urls = []
  backport_to_branches(dir, branch_prefix: 'rpm', timestamp: timestamp, pr_urls: pr_urls)
  backport_to_branches(dir, branch_prefix: 'deb', timestamp: timestamp, pr_urls: pr_urls)

  puts "\nBackport complete!".green
  unless pr_urls.empty?
    puts "\nPull requests:".magenta
    pr_urls.each { |url| puts "  #{url}" }
  end
end
