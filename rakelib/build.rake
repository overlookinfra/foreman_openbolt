# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require_relative 'utils/shell'
require_relative 'utils/container'

FOREMAN_PACKAGING_REPO = ENV.fetch('FOREMAN_PACKAGING_REPO', 'https://github.com/theforeman/foreman-packaging.git')
GEMSPEC = 'foreman_openbolt.gemspec'
GEM_FILENAME = "foreman_openbolt-#{Gem::Specification.load(GEMSPEC).version}.gem".freeze

def foreman_packaging_path(foreman_version)
  @foreman_packaging_path ||= begin
    branch = "rpm/#{foreman_version}"
    dir = File.join(Dir.tmpdir, "foreman-packaging-#{foreman_version}")
    if File.directory?(dir)
      puts "Updating foreman-packaging (#{foreman_version})...".magenta
      Shell.run(['git', '-C', dir, 'fetch', '--depth', '1', 'origin', branch])
      Shell.run(['git', '-C', dir, 'reset', '--hard', 'FETCH_HEAD'])
    else
      puts "Cloning foreman-packaging (#{foreman_version})...".magenta
      Shell.run(['git', 'clone', '--depth', '1', '--branch', branch,
                 FOREMAN_PACKAGING_REPO, dir])
    end
    dir
  end
end

def build_rpm_builder_image(foreman_version)
  image_name = "foreman-rpm-builder:#{foreman_version}"
  return image_name if Container.image_exists?(image_name)

  puts "Building RPM builder image for Foreman #{foreman_version}...".magenta
  Container.build_image(
    tag: 'foreman-packaging-base',
    dockerfile: File.join(foreman_packaging_path(foreman_version), 'Containerfile'),
    platform: 'linux/amd64'
  )

  Container.prepare_image(target_tag: image_name,
    base_image: 'foreman-packaging-base', setup_name: 'rpm-builder-setup') do |runner|
    runner.run(<<~BASH, platform: 'linux/amd64')
      set -e
      dnf install -y glibc-langpack-en
      dnf install -y https://yum.theforeman.org/releases/#{foreman_version}/el9/x86_64/foreman-release.rpm
      dnf install -y rubygems-devel foreman-plugin foreman-assets rubygem-foreman-tasks
      rpmdev-setuptree
    BASH
  end
end

def build_deb_builder_image(foreman_version)
  image_name = "foreman-deb-builder:#{foreman_version}"
  return image_name if Container.image_exists?(image_name)

  puts "Building DEB builder image for Foreman #{foreman_version}...".magenta

  Container.prepare_image(target_tag: image_name,
    base_image: 'debian:bookworm', setup_name: 'deb-builder-setup') do |runner|
    runner.run(<<~BASH, platform: 'linux/amd64')
      set -e
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y wget gnupg ca-certificates
      echo "deb http://deb.theforeman.org/ bookworm #{foreman_version}" \
        > /etc/apt/sources.list.d/foreman.list
      echo "deb http://deb.theforeman.org/ plugins #{foreman_version}" \
        >> /etc/apt/sources.list.d/foreman.list
      wget -qO- https://deb.theforeman.org/foreman.asc | gpg --dearmor \
        > /etc/apt/trusted.gpg.d/foreman.gpg
      apt-get update
      apt-get install -y gem2deb debhelper ruby ruby-dev
    BASH
  end
end

namespace :build do
  desc 'Build the gem'
  task :gem do
    FileUtils.mkdir_p('pkg')
    FileUtils.rm_f(Dir.glob('pkg/foreman_openbolt-*.gem'))
    Shell.run(['gem', 'build', GEMSPEC])
    FileUtils.mv(GEM_FILENAME, 'pkg/')
  end

  desc 'Build RPM using foreman-packaging container'
  task rpm: :gem do
    FileUtils.rm_f(Dir.glob('pkg/rubygem-foreman_openbolt-*.rpm'))

    Container.run_once(
      image: build_rpm_builder_image(FOREMAN_VERSION),
      cmd: <<~BASH,
        set -e
        cp /build/pkg/#{GEM_FILENAME} ~/rpmbuild/SOURCES/
        gem2rpm -t /build/foreman_openbolt.spec.erb \
          ~/rpmbuild/SOURCES/#{GEM_FILENAME} > ~/rpmbuild/SPECS/rubygem-foreman_openbolt.spec
        rpmbuild -ba ~/rpmbuild/SPECS/rubygem-foreman_openbolt.spec
        cp ~/rpmbuild/RPMS/noarch/rubygem-foreman_openbolt-*.rpm /build/pkg/
      BASH
      volumes: { Dir.pwd => '/build', foreman_packaging_path(FOREMAN_VERSION) => '/opt/foreman-packaging' },
      platform: 'linux/amd64'
    )

    puts "RPM built: #{Dir.glob('pkg/rubygem-foreman_openbolt-*.rpm').first}".green
  end

  desc 'Build DEB using Debian container'
  task deb: :gem do
    FileUtils.rm_f(Dir.glob('pkg/ruby-foreman-openbolt*.deb'))
    Container.run_once(
      image: build_deb_builder_image(FOREMAN_VERSION),
      cmd: <<~BASH,
        set -e
        mkdir -p /build-deb/cache
        cp /build/pkg/#{GEM_FILENAME} /build-deb/cache/
        cd /build-deb
        gem2deb --gem-install /build-deb/cache/#{GEM_FILENAME}
        cp /build-deb/*.deb /build/pkg/
      BASH
      volumes: { Dir.pwd => '/build' },
      platform: 'linux/amd64'
    )

    puts "DEB built: #{Dir.glob('pkg/ruby-foreman-openbolt*.deb').first}".green
  end
end
