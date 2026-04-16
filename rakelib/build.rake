# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require_relative 'utils/shell'
require_relative 'utils/container'

FOREMAN_PACKAGING_REPO = ENV.fetch('FOREMAN_PACKAGING_REPO', 'https://github.com/theforeman/foreman-packaging.git')
GEMSPEC = 'foreman_openbolt.gemspec'
GEM_VERSION = Gem::Specification.load(GEMSPEC).version.to_s.freeze
GEM_FILENAME = "foreman_openbolt-#{GEM_VERSION}.gem".freeze

def foreman_packaging_path(foreman_version, branch_prefix: 'rpm')
  @foreman_packaging_paths ||= {}
  key = "#{branch_prefix}-#{foreman_version}"
  @foreman_packaging_paths[key] ||= begin
    branch = "#{branch_prefix}/#{foreman_version}"
    dir = File.join(Dir.tmpdir, "foreman-packaging-#{key}")
    if File.directory?(dir)
      puts "Updating foreman-packaging (#{branch})...".magenta
      Shell.run(['git', '-C', dir, 'fetch', '--depth', '1', 'origin', branch])
      Shell.run(['git', '-C', dir, 'reset', '--hard', 'FETCH_HEAD'])
    else
      puts "Cloning foreman-packaging (#{branch})...".magenta
      Shell.run(['git', 'clone', '--depth', '1', '--branch', branch,
                 FOREMAN_PACKAGING_REPO, dir])
    end
    dir
  end
end

def build_rpm_builder_image(foreman_version)
  image_name = "foreman-openbolt-rpm-builder:#{foreman_version}"
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
      pip3 install semver
      rpmdev-setuptree
    BASH
  end
end

def build_deb_builder_image(foreman_version)
  image_name = "foreman-openbolt-deb-builder:#{foreman_version}"
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
      wget -qO- https://deb.nodesource.com/setup_22.x | bash -
      apt-get update
      apt-get install -y gem2deb debhelper rake ruby ruby-dev nodejs \
        foreman-assets foreman-nulldb ruby-foreman-tasks
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
        GEM=~/rpmbuild/SOURCES/#{GEM_FILENAME}
        SPEC=~/rpmbuild/SPECS/rubygem-foreman_openbolt.spec

        cp /build/pkg/#{GEM_FILENAME} "$GEM"
        cd /opt/foreman-packaging
        gem2rpm -t gem2rpm/foreman_plugin.spec.erb "$GEM" > "$SPEC"

        # foreman_plugin template leaves foreman_min_version as FIXME and npm
        # dependency sections empty; fill them from the gem contents
        UNPACKED=$(mktemp -d)
        gem unpack --target "$UNPACKED" "$GEM"
        PLUGIN_DIR="$UNPACKED/foreman_openbolt-#{GEM_VERSION}"
        REQUIRES=$(grep -Erh 'requires_foreman\\s' "$PLUGIN_DIR/lib" | sed -E 's/[^0-9.]//g; q')
        if [ -z "$REQUIRES" ]; then
          echo "ERROR: Could not extract requires_foreman version from $PLUGIN_DIR/lib" >&2
          exit 1
        fi
        sed -i "s/foreman_min_version FIXME/foreman_min_version $REQUIRES/" "$SPEC"
        /opt/foreman-packaging/update-requirements npm "$PLUGIN_DIR/package.json" "$SPEC"
        rm -rf "$UNPACKED"

        rpmbuild -ba "$SPEC"
        cp ~/rpmbuild/RPMS/noarch/rubygem-foreman_openbolt-*.rpm /build/pkg/
      BASH
      volumes: { Dir.pwd => '/build', foreman_packaging_path(FOREMAN_VERSION) => '/opt/foreman-packaging' },
      platform: 'linux/amd64'
    )

    rpm = Dir.glob('pkg/rubygem-foreman_openbolt-*.rpm').first
    abort 'RPM build produced no output file in pkg/'.red unless rpm
    puts "RPM built: #{rpm}".green
  end

  desc 'Build DEB using foreman-packaging debian directory'
  task deb: :gem do
    gem_version = GEM_VERSION
    FileUtils.rm_f(Dir.glob('pkg/ruby-foreman-openbolt*.deb'))

    deb_packaging = foreman_packaging_path(FOREMAN_VERSION, branch_prefix: 'deb')

    Container.run_once(
      image: build_deb_builder_image(FOREMAN_VERSION),
      cmd: <<~BASH,
        set -e
        export BUNDLE_ALLOW_ROOT=true

        # Copy packaging to a clean temp dir so build artifacts don't pollute
        # the foreman-packaging checkout
        BUILD_DIR=$(mktemp -d)/ruby-foreman-openbolt
        cp -a /opt/foreman-packaging-deb/plugins/ruby-foreman-openbolt "$BUILD_DIR"
        cd "$BUILD_DIR"

        mkdir -p cache
        cp /build/pkg/#{GEM_FILENAME} cache/

        # Update all version references to match the gem we're building
        echo "gem 'foreman_openbolt', '#{gem_version}'" > foreman_openbolt.rb
        sed -i "s/foreman_openbolt-[0-9.]*\\.gem/#{GEM_FILENAME}/" debian/gem.list
        sed -i "1s/([^)]*)/(#{gem_version}-1)/" debian/changelog

        dpkg-buildpackage -us -uc -b
        cp "$BUILD_DIR"/../ruby-foreman-openbolt*.deb /build/pkg/
      BASH
      volumes: { Dir.pwd => '/build', deb_packaging => '/opt/foreman-packaging-deb' },
      platform: 'linux/amd64'
    )

    deb = Dir.glob('pkg/ruby-foreman-openbolt*.deb').first
    abort 'DEB build produced no output file in pkg/'.red unless deb
    puts "DEB built: #{deb}".green
  end
end
