# ForemanPluginTemplate

[![License](https://img.shields.io/github/license/overlookinfra/foreman_openbolt.svg)](https://github.com/overlookinfra/foreman_openbolt/blob/master/LICENSE)
[![Test](https://github.com/overlookinfra/foreman_openbolt/actions/workflows/test.yml/badge.svg)](https://github.com/overlookinfra/foreman_openbolt/actions/workflows/test.yml)
[![Release](https://github.com/overlookinfra/foreman_openbolt/actions/workflows/release.yml/badge.svg)](https://github.com/overlookinfra/foreman_openbolt/actions/workflows/release.yml)
[![RubyGem Version](https://img.shields.io/gem/v/foreman_openbolt.svg)](https://rubygems.org/gems/foreman_openbolt)
[![RubyGem Downloads](https://img.shields.io/gem/dt/foreman_openbolt.svg)](https://rubygems.org/gems/foreman_openbolt)

*Introdction here*

## Installation

See [How_to_Install_a_Plugin](http://projects.theforeman.org/projects/foreman/wiki/How_to_Install_a_Plugin)
for how to install Foreman plugins

## Usage

*Usage here*

## TODO

*Todo list here*

## Contributing

Fork and send a Pull Request. Thanks!

## Copyright

Copyright (c) *year* *your name*

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

## how to release

* bump version in `lib/foreman_openbolt/version.rb` and `package.json`
* run `CHANGELOG_GITHUB_TOKEN=github_pat... bundle exec rake changelog`
* create a PR
* get a review & merge
* create and push a tag
* github actions will publish the tag

The Foreman team packages this gem as Debian package (deb) and as RedHat package (rpm).
They have a bot that will automatically propose an rpm/deb update at [github.com/theforeman/foreman-packaging](https://github.com/theforeman/foreman-packaging/pulls).
