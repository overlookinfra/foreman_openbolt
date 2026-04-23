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

Plans provide complex logic options, written in the Puppet language.
Besides the usual Puppet language functions, it's also possible to execute tasks and evaluate their responses.

## OpenBolt in Foreman!

OpenBolt is the Ansible counterpart and OpenBolt is OpenVox/Puppet native.
OpenBolt and OpenVox/Puppet integrate very well together and OpenBolt can reuse your existing code.
Since OpenBolt is a CLI only application, and most OpenVox and Puppet users run Foreman anyways, it made sense to integrate OpenBolt into Foreman, instead of writing another web UI.

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
This is usually a SSH, WinRM, or Choria connection. The Choria transport
requires OpenBolt 5.5 or later and is not available in Puppet Bolt.
SSH and WinRM transports work with any version.

You need to have `bolt` in your `$PATH` on the Smartproxy.
OpenBolt packages are available at [yum.voxpupuli.org](https://yum.voxpupuli.org/) & [apt.voxpupuli.org](https://apt.voxpupuli.org/) in the openvox8 repo.
You can also use the legacy Bolt packages from Perforce from the `puppet-tools` repo on [apt.puppet.com](https://apt.puppet.com/) or [yum.puppet.com](https://yum.puppet.com/).

The integration is supported on Foreman 3.17 and all following versions, including development/nightly builds.

OpenBolt relies on Tasks & Plans. They are distributed as modules.
The plugin assumes that you deployed your code.
We recommend to use [r10k](https://github.com/puppetlabs/r10k?tab=readme-ov-file#r10k) or [g10k](https://github.com/xorpaul/g10k?tab=readme-ov-file#g10k) to deploy code, as you do it on your compilers.

A handful of core/default Tasks & Plans are also included in the [OpenBolt rpm/deb packages](https://github.com/OpenVoxProject/openbolt/blob/main/Puppetfile).

## Documentation

- [Usage](docs/usage.md): screenshots and walkthrough of the UI
- [Development](docs/development.md): linting, unit tests, acceptance tests, building packages
- [Releasing](docs/releasing.md): version locations, release steps, RPM/DEB packaging
- [Choria Testing](docs/choria-testing.md): setting up Choria on a Foreman install for transport testing

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
