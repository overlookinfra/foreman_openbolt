# foreman-openbolt

[![License](https://img.shields.io/github/license/overlookinfra/foreman_openbolt.svg)](https://github.com/overlookinfra/foreman_openbolt/blob/master/LICENSE)
[![Test](https://github.com/overlookinfra/foreman_openbolt/actions/workflows/test.yml/badge.svg)](https://github.com/overlookinfra/foreman_openbolt/actions/workflows/test.yml)
[![Release](https://github.com/overlookinfra/foreman_openbolt/actions/workflows/release.yml/badge.svg)](https://github.com/overlookinfra/foreman_openbolt/actions/workflows/release.yml)
[![RubyGem Version](https://img.shields.io/gem/v/foreman_openbolt.svg)](https://rubygems.org/gems/foreman_openbolt)
[![RubyGem Downloads](https://img.shields.io/gem/dt/foreman_openbolt.svg)](https://rubygems.org/gems/foreman_openbolt)

Bringing OpenBolt Task & Plans into Foreman!

## Introduction

[OpenBolt](https://github.com/OpenVoxProject/openbolt) is the open source successor of [Bolt](https://github.com/puppetlabs/bolt) by [Perforce](https://www.perforce.com/).
OpenBolt supports running Tasks or Plans against various targets  via different transport protocols.
OpenBolt and Bolt are CLI-only tools.
They connect to the targets from a central location (usually a jumpnode or workstation).

## Tasks

Tasks are little executeable things, like binaries or scripts.
They are enhanced with a metadata file, which describes input and output parameters.
A task is copied to N targets and executed there.

## Plans

Plans provide complex logic options, written in Puppet DSL.
Besides the usual Puppet DSL functions, it's also possible to execute tasks and evaluate their responses.

## OpenBolt in Foreman!

OpenBolt is the Ansible counterpart and OpenBolt is Puppet "native".
OpenBolt and Puppet integrate very well together and OpenBolt can reuse your existing Puppet code.
Since OpenBolt is a CLI only application, and most Puppet users run Foreman anyways, it made sense to integrate OpenBolt into Foreman, instead of writing another web UI.

## Installation

The installation is split into four parts:

* Foreman Plugin
* Foreman Smartproxy Plugin
* OpenBolt
* Code Deployment

See [How_to_Install_a_Plugin](https://theforeman.org/plugins/#2.Installation) for how to install Foreman plugins.
The [theforeman/foreman](https://github.com/theforeman/puppet-foreman/blob/master/manifests/plugin/openbolt.pp) puppet module also supports the **Foreman plugin** installation.
The [theforeman/foreman_proxy](https://github.com/theforeman/puppet-foreman_proxy/blob/master/manifests/plugin/openbolt.pp) puppet module also supports the **Foreman Smartproxy plugin** installation.


The Foreman plugin provides UI elements to start Tasks on various nodes.
Foreman then talks to a Smartproxy to run OpenBolt.
The Smartproxy also establishes the connections to the various targets.
This is usually a ssh or WinRM connection (and soon choria, see [the TODO section](#todo)).

You need to have `bolt` in your `$PATH` on the Smartproxy.
OpenBolt packages are available at [yum.voxpupuli.org](https://yum.voxpupuli.org/) & [apt.voxpupuli.org](https://apt.voxpupuli.org/) in the openvox8 repo.
You can also use the legacy Bolt packages from Perforce from the `puppet-tools` repo on [apt.puppet.com](https://apt.puppet.com/) or [yum.puppet.com](https://yum.puppet.com/).

The integration is supported on Foreman 3.17 and all following versions, including development/nightly builds.

OpenBolt relies on Tasks & Plans. They are distributed as puppet modules.
The plugin assumes that you deployed your code.
We recommend to use [r10k](https://github.com/puppetlabs/r10k?tab=readme-ov-file#r10k) or [g10k](https://github.com/xorpaul/g10k?tab=readme-ov-file#g10k) to deploy code, as you do it on your compilers.

A handful of core/default Tasks & Plans are also included in the [OpenBolt rpm/deb packages](https://github.com/OpenVoxProject/openbolt/blob/main/Puppetfile).

## Usage

(all screenshots were taken on Foreman 3.17)

After installation, you will see a new UI element

![foreman UI menu screenshot](./ext/foreman-ui-menu.png)

The "Launch Task" option allows you to select any smartproxy with the `openbolt` feature (which is available when the OpenBolt Smartproxy plugin is installed).
Afterwards you can select N targets to run the task and select an available task from the selected Smartproxy.
On the right side you can configure OpenBolt connection settings.

![launch task detail view](./ext/foreman-launch-task.png)

After selecting a task, the task metadata is fetched and shown.
Additional input elements will appear, if the task support it.

![service task metadata](./ext/task-metadata-minimal.png)

The metadata can contains a description and datatypes for tasks.
Those information can be shown as well.

![service task detailed metadata](./ext/task-metadata.png)

While the task is running, the UI polls the status from the smart proxy.

![task loading screen](./ext/task-running.png)

After the task finished, it will display a success for failure page.

![failed task view](./ext/task-execution-details.png)

You can also see the used parameters for a task.

![task used parameters](./ext/task-task-details.png)

We also display the used OpenBolt command line, in case you want to manually run it or debug it.

![display used OpenBolt command](./ext/task-log-output.png)

OpenBolt returns JSON for executed tasks.
That's visible in the UI.
For failed tasks but also for passed tasks.

![failed task output](./ext/task-result.png)

![service task passed on two nodes](./ext/task-successful-result.png)

## Development

### Linting

```bash
bundle exec rake lint        # Run all linters (rubocop, erb_lint, eslint)
bundle exec rake lint:fix    # Auto-fix where possible
```

Ruby and ERB linters run directly. The JavaScript linter requires npm dependencies, so either install them locally (`npm install --legacy-peer-deps`) or run lint:js inside a container:

```bash
CONTAINER=1 bundle exec rake lint:js
```

### Unit Tests

Unit tests run inside Docker containers with a full Foreman installation. Requires Docker with compose support.

```bash
bundle exec rake test:unit:up    # Build image, start containers, install deps
bundle exec rake test:unit:ruby  # Run Ruby tests
bundle exec rake test:unit:js    # Run JavaScript tests
bundle exec rake test:unit:all   # Run all unit tests
bundle exec rake test:unit:down  # Stop and remove containers
bundle exec rake test              # Shortcut: up, test, down in one step
```

Set `FOREMAN_VERSION` to test against a specific Foreman version (default: `3.18`):

```bash
FOREMAN_VERSION=3.17 bundle exec rake test:unit:up
```

### Acceptance Tests

Acceptance tests exercise the plugin through the browser using Capybara and Selenium. They build RPMs, start a multi-container environment (Foreman + OpenVox + SSH targets + Chromium), and run tests against the real UI.

**Prerequisites:**

```bash
bundle install --with acceptance
```

The [smart_proxy_openbolt](https://github.com/overlookinfra/smart_proxy_openbolt) and [foreman-packaging](https://github.com/theforeman/foreman-packaging) repos are cloned automatically when needed.

**Running:**

```bash
bundle exec rake acceptance         # Full cycle: up, run tests, down
bundle exec rake acceptance:up      # Build RPMs, start Foreman, configure everything
bundle exec rake acceptance:run     # Run tests (requires up first)
bundle exec rake acceptance:down    # Stop containers
bundle exec rake acceptance:clean   # Full reset: stop containers, remove images and artifacts
```

The `acceptance:up` task is idempotent and can be re-run to pick up new RPM changes. It caches the Foreman Docker image per version so subsequent runs are faster.

**Watching tests in the browser:**

Set `HEADFUL=1` to disable headless mode, then open `http://localhost:7900` (password: `secret`) to watch the tests via noVNC:

```bash
HEADFUL=1 bundle exec rake acceptance:run
```

**Running a subset of tests:**

`acceptance:run` accepts `TEST=<path>` to limit which test files are loaded, and `TESTOPTS=<opts>` to forward options (e.g. `--name=/pattern/`) to the Test::Unit autorunner. Both can be combined.

```bash
# Run every test in one file
bundle exec rake acceptance:run TEST=test/acceptance/tests/settings_test.rb

# Run a single test by exact method name (any file)
bundle exec rake acceptance:run TESTOPTS='--name=test_echo_task_succeeds_on_all_targets'

# Run tests whose name matches a regex within one file
bundle exec rake acceptance:run \
  TEST=test/acceptance/tests/settings_test.rb \
  TESTOPTS='--name=/host_key/'
```

**Environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `CHROMEDRIVER_URL` | `http://localhost:4444` | Selenium WebDriver endpoint |
| `FOREMAN_BRANCH` | `<version>-stable` | Foreman git branch for unit test image (derived from `FOREMAN_VERSION`) |
| `FOREMAN_PACKAGING_REPO` | `https://github.com/theforeman/foreman-packaging.git` | Git URL for foreman-packaging (cloned automatically for RPM builds) |
| `FOREMAN_PASS` | `changeme` | Foreman login password |
| `FOREMAN_URL` | `https://foreman` | Foreman URL as seen by Chrome. Override to run tests against a live instance |
| `FOREMAN_USER` | `admin` | Foreman login username |
| `FOREMAN_VERSION` | `3.18` | Foreman version to test against |
| `HEADFUL` | unset | Set to `1` to show the browser in noVNC |
| `SELENIUM_IMAGE` | auto-detected (ARM/x86) | Selenium container image (auto-selects `seleniarm/standalone-chromium` or `selenium/standalone-chrome`) |
| `SMART_PROXY_OPENBOLT_REF` | `main` | Branch or tag to clone |
| `SMART_PROXY_OPENBOLT_REPO` | `https://github.com/overlookinfra/smart_proxy_openbolt.git` | Git URL for smart_proxy_openbolt (cloned automatically for RPM builds) |

### Building Packages

Build RPM or DEB packages locally using containers. The [foreman-packaging](https://github.com/theforeman/foreman-packaging) repo is cloned automatically:

```bash
bundle exec rake build:rpm   # Build RPM
bundle exec rake build:deb   # Build DEB
```

## TODO

* Integrate plans into the web UI
* Provide a choria transport plugin

## Contributing & support

Fork and send a Pull Request. Thanks!
If you have questions or need professional support, please join the `#sig-orchestrator` channel on the [Vox Pupuli slack](https://voxpupuli.org/connect/).

## Copyright

Copyright (c) *2025* *Overlook InfraTech*

Copyright (c) *2025* *betadots GmbH*

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

## How to Release

### Version locations

The version is maintained in two files:

1. `lib/foreman_openbolt/version.rb` -- the gem version (authoritative source)
2. `package.json` -- the npm package version (must match)

If the minimum Foreman version changes, also update:

3. `lib/foreman_openbolt/engine.rb` -- `requires_foreman '>= X.Y.Z'`
4. `.github/workflows/build.yml` -- default `foreman_version` and `foreman_packaging_ref` inputs

### Release steps

1. Go to [Actions > Prepare Release](../../actions/workflows/prepare_release.yml) and run the workflow with the version to release (e.g. `1.2.0`)
2. The workflow bumps the version in `version.rb` and `package.json`, generates the changelog, and opens a PR with the `skip-changelog` label
3. Review and merge the PR
4. Go to [Actions > Release](../../actions/workflows/release.yml) and run the workflow with the same version
5. The release workflow:
   - Verifies the version in `version.rb` matches the input
   - Creates and pushes a git tag
   - Builds the gem
   - Creates a GitHub Release with auto-generated notes and the gem attached
   - Publishes the gem to GitHub Packages
   - Publishes the gem to RubyGems.org (requires the `release` environment)
   - Verifies the gem is available on RubyGems.org

### RPM/DEB packaging

After the gem is published to RubyGems, both RPM and DEB packages need to be updated in [theforeman/foreman-packaging](https://github.com/theforeman/foreman-packaging).

A bot automatically creates PRs against the `rpm/develop` and `deb/develop` branches to pick up the new gem version. These PRs build packages for Foreman nightly.

For stable Foreman releases (currently 3.17 and 3.18), cherry-pick the packaging commits from the develop branches into the corresponding stable branches. For each stable version you want to support:

```bash
cd foreman-packaging

# RPM: cherry-pick from rpm/develop into a branch off the stable target
git checkout rpm/3.18
git checkout -b cherry-pick/rubygem-foreman_openbolt-rpm-3.18
git cherry-pick <commit-from-rpm/develop>
# Push to your fork and open a PR targeting rpm/3.18

# DEB: same approach for the deb side
git checkout deb/3.18
git checkout -b cherry-pick/rubygem-foreman-openbolt-deb-3.18
git cherry-pick <commit-from-deb/develop>
# Push to your fork and open a PR targeting deb/3.18
```

PRs against stable branches should be labeled "Stable branch".

**Alternative: manual version bump**

If the cherry-pick doesn't apply cleanly, you can bump the version manually on the stable branch instead.

*RPM:* Checkout the target branch and run `bump_rpm.sh`:
```bash
cd foreman-packaging
git checkout rpm/3.18
git checkout -b bump_rpm/rubygem-foreman_openbolt
./bump_rpm.sh packages/plugins/rubygem-foreman_openbolt
# Review changes, push to your fork, and open a PR targeting rpm/3.18
```

*DEB:* Checkout the target branch and update these files:
- `debian/gem.list` -- new gem filename
- `foreman_openbolt.rb` -- new version
- `debian/control` -- dependency versions (if changed)
- `debian/changelog` -- add a new entry

```bash
git checkout deb/3.18
git checkout -b bump_deb/ruby-foreman-openbolt
# Make the changes above, push to your fork, and open a PR targeting deb/3.18
```
