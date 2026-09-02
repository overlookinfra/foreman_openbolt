# frozen_string_literal: true

require 'tmpdir'
require_relative 'utils/shell'

FOREMAN_PACKAGING_UPSTREAM_URL = 'https://github.com/theforeman/foreman-packaging'
BACKPORT_GEMS = %w[smart_proxy_openbolt foreman_openbolt].freeze

def backport_gems
  only = ENV['ONLY']
  if only
    abort "Unknown gem '#{only}'. Valid values for ONLY are #{BACKPORT_GEMS.join(', ')}.".red unless BACKPORT_GEMS.include?(only)
    return [only]
  end

  if ENV['RPM_COMMIT'] || ENV['DEB_COMMIT'] || ENV['VERSION']
    abort 'RPM_COMMIT, DEB_COMMIT and VERSION apply to a single gem. Set ONLY=<gem> to name it.'.red
  end

  BACKPORT_GEMS
end

# With a single commit override, only that package type gets backported.
def backport_prefixes
  overrides = %w[rpm deb].select { |prefix| ENV["#{prefix.upcase}_COMMIT"] }
  overrides.empty? ? %w[rpm deb] : overrides
end

def packaging_name(gem_name, branch_prefix)
  return "rubygem-#{gem_name}" if branch_prefix == 'rpm'

  "ruby-#{gem_name.tr('_', '-')}"
end

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

def parse_bump_commit(line)
  sha, message = line.split(' ', 2)
  version_match = message.match(/to (\d+\.\d+\.\d+)/)
  gem_version = version_match ? version_match[1] : 'unknown'

  { sha: sha, message: message, version: gem_version }
end

def find_bump_commit(dir, branch, package_name)
  result = Shell.capture(
    ['git', '-C', dir, 'log', branch, '-1', '--format=%H %s', '--grep', package_name],
    print_command: false
  )
  line = result.output.strip
  abort "No commit found for '#{package_name}' on #{branch}".red if line.empty?

  parse_bump_commit(line)
end

def specified_commit(dir, sha, develop_ref)
  ancestor = Shell.capture(
    ['git', '-C', dir, 'merge-base', '--is-ancestor', sha, develop_ref],
    print_command: false, allowed_exit_codes: [0, 1]
  )
  abort "Commit #{sha} is not on #{develop_ref}".red unless ancestor.exitcode.zero?

  result = Shell.capture(['git', '-C', dir, 'log', '-1', '--format=%H %s', sha], print_command: false)
  parse_bump_commit(result.output.strip)
end

# Cherry-picks a commit, pausing for manual resolution if it does not apply cleanly.
# Returns true if the commit landed, false if it was aborted or skipped during resolution.
def cherry_pick_commit(dir, sha)
  head_before = Shell.capture(['git', '-C', dir, 'rev-parse', 'HEAD'], print_command: false).output
  exitcode = Shell.run(['git', '-C', dir, 'cherry-pick', sha], allowed_exit_codes: [0, 1])
  return true if exitcode.zero?

  puts "\nCherry-pick of #{sha[0..7]} did not apply cleanly.".yellow
  puts "Resolve it in #{dir} and finish with git cherry-pick --continue.".yellow
  loop do
    print 'Press Enter once the cherry-pick is finished (Ctrl-C aborts the backport)... '
    $stdout.flush
    abort 'Stdin is closed, cannot wait for conflict resolution.'.red if $stdin.gets.nil?
    break unless File.exist?(File.join(dir, '.git', 'CHERRY_PICK_HEAD'))

    puts 'The cherry-pick is still in progress, finish it first.'.yellow
  end

  head_after = Shell.capture(['git', '-C', dir, 'rev-parse', 'HEAD'], print_command: false).output
  return true unless head_after == head_before

  puts "  Cherry-pick of #{sha[0..7]} did not add a commit (aborted or skipped), leaving it out".yellow
  false
end

# Asks a yes/no question when running interactively. Returns true without
# asking when stdin is not a TTY so non-interactive runs keep working.
def confirm?(question)
  return true unless $stdin.tty?

  print "#{question} [y/N] "
  $stdout.flush
  answer = $stdin.gets
  return false if answer.nil?

  %w[y yes].include?(answer.strip.downcase)
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

def backport_to_branches(dir, gems:, branch_prefix:, timestamp:, pr_urls:)
  develop_ref = "upstream/#{branch_prefix}/develop"
  override_sha = ENV["#{branch_prefix.upcase}_COMMIT"]
  override_version = ENV['VERSION']

  puts "\nLooking for package bump commits on #{develop_ref}...".magenta

  commits = gems.map do |gem_name|
    package = packaging_name(gem_name, branch_prefix)
    found = if override_sha
              specified_commit(dir, override_sha, develop_ref)
            else
              find_bump_commit(dir, develop_ref, package)
            end
    commit = found.merge(gem: gem_name)
    commit[:version] = override_version if override_version
    puts "  #{package}: #{commit[:sha][0..7]} (#{commit[:version]})".green
    commit
  end

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
    landed = commits.select { |commit| cherry_pick_commit(dir, commit[:sha]) }
    if landed.empty?
      puts "  Nothing was cherry-picked for #{branch_prefix}/#{version}, skipping".yellow
      next
    end
    Shell.run(['git', '-C', dir, 'push', 'origin', branch_name])
    puts "  Pushed #{branch_name}".green

    next unless use_gh

    picked = landed.map { |commit| "#{commit[:gem]} #{commit[:version]}" }.join(' and ')
    pr_title = "Cherry pick #{picked} to #{branch_prefix}/#{version}"
    if $stdin.tty?
      puts "\nChanges for the #{branch_prefix}/#{version} PR:".magenta
      Shell.run(['git', '-C', dir, '--no-pager', 'log', '-p', "#{target_ref}..#{branch_name}"], print_command: false)
    end
    unless confirm?("  Create PR '#{pr_title}'?")
      puts "  Skipped PR for #{branch_prefix}/#{version}".yellow
      next
    end

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

desc 'Cherry-pick OpenBolt package bumps to all supported Foreman release branches in foreman-packaging ' \
     '(set ONLY=<gem> to backport a single gem, RPM_COMMIT/DEB_COMMIT to pick commits instead of the latest, ' \
     'VERSION to override the version in PR titles)'
task :backport do
  gems = backport_gems
  prefixes = backport_prefixes
  verify_gh_permissions
  dir = clone_foreman_packaging
  timestamp = Time.now.utc.strftime('%Y-%m-%d_%H-%M-%S')
  versions = supported_foreman_releases

  puts "Backporting gems: #{gems.join(', ')}".magenta
  puts "Package types: #{prefixes.join(', ')}".magenta
  puts "Supported Foreman releases: #{versions.join(', ')}".magenta
  puts "Backport timestamp: #{timestamp}".magenta

  pr_urls = []
  prefixes.each do |prefix|
    backport_to_branches(dir, gems: gems, branch_prefix: prefix, timestamp: timestamp, pr_urls: pr_urls)
  end

  puts "\nBackport complete!".green
  unless pr_urls.empty?
    puts "\nPull requests:".magenta
    pr_urls.each { |url| puts "  #{url}" }
  end
end
