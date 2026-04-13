# frozen_string_literal: true

require_relative 'shell'

class Container
  attr_reader :name, :image

  def initialize(name:, image:)
    @name = name
    @image = image
  end

  # --- Class methods for stateless operations ---

  def self.compose(file, *args)
    Shell.run(['docker', 'compose', '-f', file, *args])
  end

  def self.image_exists?(image_name)
    # exit 1 = image not found
    Shell.capture(['docker', 'image', 'inspect', image_name],
      print_command: false, allowed_exit_codes: [0, 1]).exitcode == 0
  end

  def self.build_image(dockerfile:, tag: 'latest', context: nil, build_args: {}, platform: nil)
    context ||= File.dirname(dockerfile)
    cmd = ['docker', 'build', '-t', tag, '-f', dockerfile]
    cmd.push('--platform', platform) if platform
    build_args.each { |key, val| cmd.push('--build-arg', "#{key}=#{val}") }
    cmd << context
    Shell.run(cmd)
  end

  # Ensure an image exists by running a block with a temporary container
  # and committing the result. Skips if the image already exists.
  # Returns the target tag.
  def self.prepare_image(target_tag:, base_image:, setup_name:)
    return target_tag if image_exists?(target_tag)
    runner = new(name: setup_name, image: base_image)
    begin
      yield runner
      runner.commit(target_tag)
    rescue StandardError => e
      begin
        runner.teardown
      rescue StandardError => teardown_error
        warn "WARNING: teardown also failed: #{teardown_error.message}".yellow
      end
      raise e
    else
      runner.teardown
    end
    puts "Image #{target_tag} committed.".green
    target_tag
  end

  def self.run_once(image:, cmd:, volumes: {}, platform: nil)
    args = ['docker', 'run', '--rm']
    args.push('--platform', platform) if platform
    volumes.each { |host_path, container_path| args.push('-v', "#{host_path}:#{container_path}") }
    args.push(image, 'bash', '-c', cmd)
    Shell.run(args)
  end

  # --- Instance methods for named container lifecycle ---

  # Run a command in a new named container (blocks until done).
  def run(cmd, platform: nil)
    args = ['docker', 'run', '--name', name]
    args.push('--platform', platform) if platform
    args.push(image, 'bash', '-c', cmd)
    Shell.run(args)
  end

  # Start a detached named container (returns immediately).
  def start(platform: nil, privileged: false, hostname: nil, tmpfs: [])
    cmd = ['docker', 'run', '-d', '--name', name]
    cmd.push('--platform', platform) if platform
    cmd << '--privileged' if privileged
    cmd.push('--hostname', hostname) if hostname
    tmpfs.each { |mount| cmd.push('--tmpfs', mount) }
    cmd << image
    Shell.run(cmd)
  end

  # Execute a command inside the running container.
  def exec(cmd, tty: false, allowed_exit_codes: [0])
    args = ['docker', 'exec']
    args << '-t' if tty
    args.push(name, 'bash', '-c', cmd)
    Shell.run(args, allowed_exit_codes: allowed_exit_codes)
  end

  def stop
    Shell.run(['docker', 'stop', name])
  end

  def commit(target_image)
    Shell.run(['docker', 'commit', name, target_image])
  end

  # Force-remove the container (safe for ensure blocks).
  # exit 1 = container doesn't exist
  def teardown
    Shell.run(['docker', 'rm', '-f', name], print_command: false, allowed_exit_codes: [0, 1])
  end
end
