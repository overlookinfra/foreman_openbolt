# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'rake/testtask'
require 'shellwords'
require 'tmpdir'
require_relative 'utils/container'

ACCEPTANCE_DOCKER_DIR = File.join(__dir__, '..', 'test', 'acceptance', 'docker')
ACCEPTANCE_COMPOSE = File.join(ACCEPTANCE_DOCKER_DIR, 'docker-compose.yml')
ACCEPTANCE_SSH_KEY = File.join(__dir__, '..', 'test', 'acceptance', 'fixtures', 'keys', 'id_rsa')

SMART_PROXY_REPO = ENV.fetch('SMART_PROXY_OPENBOLT_REPO', 'https://github.com/overlookinfra/smart_proxy_openbolt.git')
SMART_PROXY_REF = ENV.fetch('SMART_PROXY_OPENBOLT_REF', 'main')

FOREMAN_CONTAINER = 'foreman-openbolt-test'
FOREMAN_AUTH = 'admin:changeme'
FOREMAN_FQDN = 'foreman.example.com'
SSH_OPTS = '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR'
TARGETS = %w[target1 target2].freeze

def wait_for(description, timeout: 120, interval: 2)
  puts "==> Waiting for #{description}...".magenta
  deadline = Time.now + timeout
  loop do
    begin
      return if yield
    rescue StandardError => error
      warn "  Retrying #{description}: #{error.message}".yellow
    end
    abort "FATAL: #{description} did not become ready within #{timeout}s".red if Time.now > deadline
    sleep interval
  end
end

# --- Foreman container helpers ---

def foreman_exec(*cmd)
  Shell.run(['docker', 'exec', FOREMAN_CONTAINER, 'bash', '-c', cmd.join(' ')])
end

# quiet: true when nil is an expected outcome (e.g. checking if something exists)
def foreman_exec_capture(cmd, quiet: false)
  # exit 1 = command failed inside container (caller decides if that's fatal)
  result = Shell.capture(['docker', 'exec', FOREMAN_CONTAINER, 'bash', '-c', cmd],
    print_command: false, allowed_exit_codes: [0, 1])
  return result.output.strip if result.exitcode == 0
  warn "foreman_exec_capture failed (exit #{result.exitcode}): #{cmd}\n  output: #{result.output}".yellow unless quiet
  nil
end

def target_ssh(target, cmd)
  foreman_exec("ssh #{SSH_OPTS} -i /opt/foreman-proxy/.ssh/id_rsa openbolt@#{target} '#{cmd}'")
end

def target_ssh_capture(target, cmd, quiet: false)
  foreman_exec_capture("ssh #{SSH_OPTS} -i /opt/foreman-proxy/.ssh/id_rsa openbolt@#{target} \"#{cmd}\"", quiet: quiet)
end

def foreman_api(method, path, data = nil)
  curl = "curl -sk -u #{FOREMAN_AUTH} -H 'Accept: application/json'"
  curl += " -H 'Content-Type: application/json'" if data
  curl += " -X #{method.upcase}" unless method.upcase == 'GET'
  curl += " -d #{Shellwords.shellescape(data)}" if data
  curl += " 'https://localhost/api/v2#{path}'"
  output = foreman_exec_capture(curl)
  return nil if output.nil? || output.empty?
  JSON.parse(output)
rescue JSON::ParserError
  warn "WARNING: Non-JSON response from #{method.upcase} #{path}: #{output[0..500]}".yellow
  nil
end

def register_target(target, fqdn, os_id:, hg_id:)
  reg_data = { registration_command: {
    insecure: true, setup_insights: false, setup_remote_execution: false,
    operatingsystem_id: os_id, hostgroup_id: hg_id,
  } }.to_json

  reg_output = foreman_exec_capture(
    "curl -sk -u #{FOREMAN_AUTH} " \
    "-H 'Accept: application/json' -H 'Content-Type: application/json' " \
    "-H 'Host: #{FOREMAN_FQDN}' " \
    "-X POST 'https://localhost/api/v2/registration_commands' " \
    "-d #{Shellwords.shellescape(reg_data)}"
  )
  begin
    reg_cmd = reg_output && JSON.parse(reg_output)['registration_command']
  rescue JSON::ParserError
    reg_cmd = nil
  end
  abort "FATAL: Could not get registration command from Foreman.\nResponse: #{reg_output}".red unless reg_cmd

  tmpfile = File.join(Dir.tmpdir, 'foreman_register.sh')
  File.write(tmpfile, reg_cmd)
  Shell.run(['docker', 'cp', tmpfile, "#{FOREMAN_CONTAINER}:/opt/foreman_register.sh"])
  FileUtils.rm_f(tmpfile)
  foreman_exec("scp #{SSH_OPTS} -i /opt/foreman-proxy/.ssh/id_rsa /opt/foreman_register.sh openbolt@#{target}:/tmp/register.sh")

  # Run with TTY so puppet output streams in real time
  reg_ssh = "ssh #{SSH_OPTS} -tt -i /opt/foreman-proxy/.ssh/id_rsa openbolt@#{target} 'sudo bash /tmp/register.sh && rm -f /tmp/register.sh'"
  Shell.run(['docker', 'exec', '-t', FOREMAN_CONTAINER, 'bash', '-c',
    reg_ssh])

  verify_result = target_ssh_capture(target, 'sudo /opt/puppetlabs/bin/puppet ssl verify')
  abort "FATAL: cert for #{fqdn} was not created".red if verify_result.nil?
end

def build_foreman_image(foreman_version)
  base_image = "foreman-openbolt-base:#{foreman_version}"
  final_image = "foreman-openbolt:#{foreman_version}"

  return final_image if Container.image_exists?(final_image)

  puts "==> Building Foreman base image...".magenta
  Container.build_image(
    tag: base_image,
    dockerfile: File.join(ACCEPTANCE_DOCKER_DIR, 'foreman', 'Dockerfile'),
    context: ACCEPTANCE_DOCKER_DIR,
    build_args: { 'FOREMAN_VERSION' => foreman_version },
    platform: 'linux/amd64'
  )

  Container.prepare_image(target_tag: final_image,
    base_image: base_image, setup_name: 'foreman-installer-setup') do |runner|
    runner.start(
      platform: 'linux/amd64',
      privileged: true,
      hostname: 'foreman.example.com',
      tmpfs: ['/run', '/tmp:rw,exec,nosuid']
    )

    wait_for('systemd in installer container', timeout: 60) do
      # exit 1 = system still starting up
      result = Shell.capture(['docker', 'exec', 'foreman-installer-setup',
        'systemctl', 'is-system-running'], print_command: false, allowed_exit_codes: [0, 1])
      %w[running degraded].include?(result.output.strip)
    end

    puts "==> Running foreman-installer...".magenta
    installer_args = %w[
      --foreman-initial-admin-username=admin
      --foreman-initial-admin-password=changeme
      --enable-foreman-plugin-puppet
      --puppet-server-foreman-url=https://foreman.example.com
      --puppet-autosign-entries=*
      --enable-foreman-proxy
      --foreman-proxy-puppet=true
      --foreman-proxy-puppetca=true
      --foreman-proxy-ssl=true
      --foreman-proxy-ssl-port=8443
      --foreman-proxy-http=false
      --foreman-proxy-tftp=false
      --foreman-proxy-dns=false
      --foreman-proxy-dhcp=false
      --foreman-proxy-bmc=false
      --foreman-proxy-realm=false
    ]
    # foreman-installer exits 2 on "success with changes"
    runner.exec("foreman-installer #{installer_args.join(' ')}", allowed_exit_codes: [0, 2])

    # Bake Foreman setup into the image so acceptance:up only needs to
    # install new plugin RPMs and run any new migrations.
    runner.exec('cd /usr/share/foreman && RAILS_ENV=production foreman-rake db:migrate')

    runner.stop
  end
end

def smart_proxy_openbolt_path
  dir = File.join(Dir.tmpdir, "smart_proxy_openbolt-#{SMART_PROXY_REF}")
  if File.directory?(dir)
    puts "Updating smart_proxy_openbolt (#{SMART_PROXY_REF})...".magenta
    Shell.run(['git', '-C', dir, 'fetch', '--depth', '1', 'origin', SMART_PROXY_REF])
    Shell.run(['git', '-C', dir, 'reset', '--hard', 'FETCH_HEAD'])
  else
    puts "Cloning smart_proxy_openbolt (#{SMART_PROXY_REF})...".magenta
    Shell.run(['git', 'clone', '--depth', '1', '--branch', SMART_PROXY_REF, SMART_PROXY_REPO, dir])
  end
  dir
end

# --- Acceptance tasks ---

namespace :acceptance do
  task :build_rpms do

    unless File.exist?(ACCEPTANCE_SSH_KEY)
      FileUtils.mkdir_p(File.dirname(ACCEPTANCE_SSH_KEY))
      Shell.run(['ssh-keygen', '-t', 'rsa', '-b', '2048', '-f', ACCEPTANCE_SSH_KEY, '-N', '', '-q'])
      File.chmod(0600, ACCEPTANCE_SSH_KEY)
    end

    foreman_rpm = Dir.glob('pkg/rubygem-foreman_openbolt-*.rpm').first
    proxy_rpm = Dir.glob('pkg/rubygem-smart_proxy_openbolt-*.rpm').first

    if foreman_rpm
      puts "==> Using existing foreman_openbolt RPM: #{File.basename(foreman_rpm)}".magenta
    else
      puts "==> Building foreman_openbolt RPM...".magenta
      Rake::Task['build:rpm'].invoke
    end

    if proxy_rpm
      puts "==> Using existing smart_proxy_openbolt RPM: #{File.basename(proxy_rpm)}".magenta
    else
      puts "==> Building smart_proxy_openbolt RPM...".magenta
      proxy_dir = smart_proxy_openbolt_path
      Dir.chdir(proxy_dir) do
        Bundler.with_unbundled_env do
          Shell.run(['bundle', 'install'])
          Shell.run(['bundle', 'exec', 'rake', 'build:rpm'])
        end
      end
      FileUtils.cp(Dir.glob(File.join(proxy_dir, 'pkg', 'rubygem-smart_proxy_openbolt-*.rpm')), 'pkg')
    end
  end

  task start: :build_rpms do
    # FOREMAN_IMAGE is passed to compose
    ENV['FOREMAN_IMAGE'] = build_foreman_image(FOREMAN_VERSION)
    ENV['SELENIUM_IMAGE'] ||= RUBY_PLATFORM.match?(/arm|aarch64/) ? 'seleniarm/standalone-chromium:latest' : 'selenium/standalone-chrome:latest'

    puts "==> Starting containers...".magenta
    Container.compose(ACCEPTANCE_COMPOSE, 'up', '-d', '--wait')
  end

  desc 'Build RPMs, start containers, and configure Foreman for acceptance tests'
  task up: :start do
    # Install plugin RPMs (remove old versions first if present)
    puts "==> Installing plugin RPMs...".magenta
    %w[rubygem-foreman_openbolt rubygem-smart_proxy_openbolt].each do |pkg|
      foreman_exec("dnf remove -y #{pkg}") if foreman_exec_capture("rpm -q #{pkg}", quiet: true)
    end
    foreman_exec('dnf install -y /opt/pkg/rubygem-foreman_openbolt-*.rpm /opt/pkg/rubygem-smart_proxy_openbolt-*.rpm')

    # Verify SSH connectivity (key setup is handled by container entrypoint)
    puts "==> Verifying SSH connectivity to targets...".magenta
    TARGETS.each do |target|
      abort "FATAL: SSH to #{target} failed".red unless target_ssh_capture(target, 'echo ok')
      puts "    SSH to #{target}: OK"
    end

    puts "==> Running database migrations...".magenta
    foreman_exec('cd /usr/share/foreman && RAILS_ENV=production foreman-rake db:migrate')

    # db:seed registers plugin settings. It may fail on some Foreman internals
    # (e.g. db_pending_seed) but our plugin's settings are typically registered
    # before the failure. The subsequent API calls will fail clearly if not.
    puts "==> Seeding plugin data...".magenta
    # exit 1 = Foreman internal seed error (db_pending_seed); plugin settings still register
    Shell.run(['docker', 'exec', FOREMAN_CONTAINER, 'bash', '-c',
      'cd /usr/share/foreman && RAILS_ENV=production foreman-rake db:seed'],
      allowed_exit_codes: [0, 1])

    # Disable bruteforce protection before restarting so API polling during
    # startup doesn't trigger a lockout. Must be done via rake (not the API)
    # because the web server isn't running yet.
    puts "==> Disabling bruteforce protection before restarting so polling doesn't trigger a lockout...".magenta
    foreman_exec('cd /usr/share/foreman && RAILS_ENV=production foreman-rake config -- -k failed_login_attempts_limit -v 0')

    # Restart services to pick up the new plugin RPMs
    puts "==> Restarting Foreman services...".magenta
    foreman_exec('systemctl restart foreman foreman-proxy')

    wait_for('Foreman to be ready') do
      foreman_api('GET', '/status')
    end
    puts '    Foreman is up.'

    # OpenBolt settings
    puts "==> Configuring Foreman settings...".magenta
    {
      'openbolt_user' => 'openbolt',
      'openbolt_private-key' => '/opt/foreman-proxy/.ssh/id_rsa',
      'openbolt_host-key-check' => false,
    }.each do |name, value|
      result = foreman_api('PUT', "/settings/#{name}", { setting: { value: value } }.to_json)
      abort "FATAL: Failed to update Foreman setting '#{name}': #{result}".red unless result
    end

    wait_for('Smart Proxy with openbolt feature', timeout: 60) do
      features = foreman_exec_capture('curl -sk https://localhost:8443/features')
      features&.include?('openbolt')
    end

    # Register Smart Proxy
    puts "==> Registering Smart Proxy with Foreman...".magenta
    unless foreman_api('GET', "/smart_proxies?search=name=#{FOREMAN_FQDN}")&.dig('results', 0, 'id')
      result = foreman_api('POST', '/smart_proxies',
        { smart_proxy: { name: FOREMAN_FQDN, url: "https://#{FOREMAN_FQDN}:8443" } }.to_json)
      abort "FATAL: Failed to register Smart Proxy with Foreman: #{result}".red unless result
      puts '    Smart Proxy registered.'
    end

    puts "==> Refreshing Smart Proxy features...".magenta
    foreman_exec('cd /usr/share/foreman && RAILS_ENV=production foreman-rake openbolt:refresh_proxies')

    wait_for('OpenVox Server to be ready', timeout: 360, interval: 3) do
      status = foreman_exec_capture('curl -sk https://localhost:8140/status/v1/simple')
      status&.include?('running')
    end

    # Look up IDs for host group and registration
    proxy_result = foreman_api('GET', '/smart_proxies')
    proxy_id = proxy_result&.dig('results', 0, 'id')
    abort "FATAL: Smart proxy lookup failed: #{proxy_result}".red unless proxy_id

    os_result = foreman_api('GET', '/operatingsystems')
    os_id = os_result&.dig('results', 0, 'id')
    abort "FATAL: Operating system lookup failed: #{os_result}".red unless os_id

    env_result = foreman_api('GET', '/environments')
    env_id = env_result&.dig('results', 0, 'id')
    abort "FATAL: Puppet environment lookup failed: #{env_result}".red unless env_id

    # Host group
    puts "==> Configuring host group for registration...".magenta
    all_hgs = foreman_api('GET', '/hostgroups?per_page=all')
    abort "FATAL: Could not list host groups from Foreman: #{all_hgs}".red unless all_hgs.is_a?(Hash)
    hg_id = all_hgs.dig('results')&.find { |hg| hg['name'] == 'acceptance' }&.dig('id')
    if hg_id
      puts '    Host group already exists.'
    else
      result = foreman_api('POST', '/hostgroups', {
        hostgroup: {
          name: 'acceptance',
          puppet_proxy_id: proxy_id,
          puppet_ca_proxy_id: proxy_id,
          environment_id: env_id,
          operatingsystem_id: os_id,
          group_parameters_attributes: [
            { name: 'enable-openvox8', value: 'true', parameter_type: 'boolean' },
          ],
        },
      }.to_json)
      abort "FATAL: Failed to create acceptance host group: #{result}".red unless result.is_a?(Hash) && result['id']
      hg_id = result['id']
      puts '    Host group created.'
    end

    # Register targets
    puts "==> Registering targets with Foreman...".magenta
    all_hosts = foreman_api('GET', '/hosts?per_page=all')
    abort "FATAL: Could not list hosts from Foreman: #{all_hosts}".red unless all_hosts.is_a?(Hash)
    known_hosts = all_hosts.dig('results')&.map { |host| host['name'] } || []

    TARGETS.each do |target|
      fqdn = target_ssh_capture(target, 'hostname -f')
      abort "FATAL: Could not get FQDN for #{target}".red if fqdn.nil? || fqdn.empty?

      if known_hosts.include?(fqdn)
        puts "    #{fqdn}: already registered in Foreman."
        next
      end

      cert_check = target_ssh_capture(target, 'sudo /opt/puppetlabs/bin/puppet ssl verify', quiet: true)
      if cert_check
        puts "    #{fqdn}: already has valid certs, skipping registration."
        next
      end

      register_target(target, fqdn, os_id: os_id, hg_id: hg_id)
      puts "    #{fqdn}: registered with certs."
    end

    # Disable puppet agent so background runs don't interfere with tests
    puts "==> Disabling puppet agent on targets...".magenta
    TARGETS.each do |target|
      target_ssh(target, 'sudo systemctl disable puppet')
      puts "    #{target}: puppet agent disabled."
    end

    puts ''
    puts '========================================='.green
    puts '  Foreman is ready at https://localhost'.green
    puts '  Admin credentials: admin / changeme'.green
    puts '========================================='.green
  end

  # Usage:
  #   rake acceptance:run
  #   rake acceptance:run TEST=test/acceptance/tests/settings_test.rb
  #   rake acceptance:run TEST=test/acceptance/tests/settings_test.rb TESTOPTS='--name=/host_key/'
  #   rake acceptance:run TESTOPTS='--name=test_echo_task_succeeds_on_all_targets'
  #
  # TEST limits which files are loaded (glob supported). TESTOPTS is passed
  # through to Test::Unit's autorunner, so --name=/pattern/ filters by test
  # method name across whichever files are loaded.
  Rake::TestTask.new(:run) do |task|
    task.libs << 'test/acceptance'
    task.test_files = FileList[ENV.fetch('TEST', 'test/acceptance/tests/**/*_test.rb')]
    task.options = ENV.fetch('TESTOPTS', '--verbose')
    task.verbose = true
  end

  desc 'Stop acceptance test containers'
  task :down do
    Container.compose(ACCEPTANCE_COMPOSE, 'down')
  end

  desc 'Stop containers and remove all data and images (full reset)'
  task :clean do
    Container.compose(ACCEPTANCE_COMPOSE, 'down', '-v', '--rmi', 'all')
    FileUtils.rm_rf('pkg')
    FileUtils.rm_rf(File.dirname(ACCEPTANCE_SSH_KEY))
    %w[foreman-openbolt-base foreman-openbolt].each do |repo|
      result = Shell.capture(['docker', 'images', '--format', '{{.Repository}}:{{.Tag}}', repo],
        print_command: false)
      result.output.each_line do |line|
        image_ref = line.strip
        next if image_ref.empty?
        # exit 1 = image not found or in use
        Shell.run(['docker', 'rmi', image_ref], allowed_exit_codes: [0, 1])
      end
    end
  end
end

desc 'Run full acceptance test cycle: up, test, down'
task :acceptance do
  Rake::Task['acceptance:up'].invoke
  Rake::Task['acceptance:run'].invoke
ensure
  begin
    Rake::Task['acceptance:down'].invoke
  rescue StandardError => error
    warn "Warning: acceptance:down cleanup failed: #{error.message}".yellow
  end
end
