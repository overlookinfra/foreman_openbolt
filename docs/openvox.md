# Starting with Foreman and OpenVox

## Preamble

There are two ways to get started.
Foreman provides the [foreman-installer](https://github.com/theforeman/foreman-installer).
This is an interactive CLI that vendors certain modules.
It uses `puppet apply` to install Foreman and openvox-server.

An alternative way, if you already have a running openvox-server, is using their modules directly.
This will be used for this example.

## Preconditions

We assume that you have a working OpenVox Server & OpenVoxDB 8.x or newer.
You can install Foreman on the same system or a dedicated VM.
Foreman can interact with other tools, for example OpenVox Server, OpenBolt or your beloved DHCP and DNS server.
This communication is done by the foreman-proxy, which runs on the same system as the tool you want to interact with.
Foreman-proxy and Foreman communicate via HTTPS and you can have multiple proxies.

To make this example more fun/realistic, we will install Foreman on a dedicated box.
The hostnames are `openvoxserver` & `foreman` (will be referenced in Hiera).

To properly test this, you should add a couple of agents.
Every system has to use the same domain and you need working DNS.

## Naming things

* The Foreman-proxy is sometimes called smartproxy
* choria-server runs on every system. it connects to the choria-broker
* choria-server & choria-broker are written in Go
* choria-broker gets requests from clients and distributes them to the correct servers
* choria-broker uses [NATS](https://nats.io/) for messaging
* You can run a HA/federated broker setup
* MCollective was a Ruby-written orchestration framework with [ActiveMQ](https://activemq.apache.org/) as broker
* MCollective could be extended with plugins, called agents
* Choria is the successor of MCollective. Choria can reuse existing mcollective agents
* In our demo, Choria reuses the TLS certificates from the OpenVox Agent. External CAs are supported as well
* We will install a single choria-broker, on the OpenVox Server

## Hiera setup

Put the following in a common Hiera layer, that every node receives:

```yaml
---
mcollective::client: true

# start choria-server everywhere
choria::server: true
# We want to use the choria.io repos
choria::manage_package_repo: true
# In case SRV records will be available, set the correct domain
choria::srvdomain: "%{facts.networking.domain}"
# info is too verbose for production environments, but nice for demos
choria::log_level: 'info'
choria::server_log_level: 'info'
# log into the systemd journal
choria::logfile: 'stdout'

mcollective_choria::config:
  security.serializer: "json"
  use_srv: false
  puppetserver_host: "openvoxserver.%{facts.networking.domain}"
  puppetserver_port: 8140
  puppetca_host: "openvoxserver.%{facts.networking.domain}"
  puppetca_port: 8140
  puppetdb_host: "openvoxserver.%{facts.networking.domain}"
  puppetdb_port: 8081
  middleware_hosts: "openvoxserver.%{facts.networking.domain}:4222"

choria::server_config:
  plugin.choria.puppetserver_host: "openvoxserver.%{facts.networking.domain}"
  plugin.choria.puppetserver_port: 8140
  plugin.choria.puppetca_host: "openvoxserver.%{facts.networking.domain}"
  plugin.choria.puppetca_port: 8140
  plugin.choria.puppetdb_host: "openvoxserver.%{facts.networking.domain}"
  plugin.choria.puppetdb_port: 8081
  plugin.choria.middleware_hosts: "openvoxserver.%{facts.networking.domain}:4222"
  # this allows us to reuse existing OpenVox Certs for Choria auth
  # .mcollective is the default domain from the upstream docs & for CLI users - but you don't have to use it
  plugin.choria.security.certname_whitelist: "\\.mcollective$,\\.%{facts.networking.domain}$"

# default policies:
# https://github.com/choria-io/puppet-mcollective/blob/74db516c307411663354e79ecb3ca3f7bc4cbec9/data/common.yaml#L27-L46
##
# gives three certs full choria access
##
# This configures *who* (which TLS client cert) is allowed to do *what* (the actions) *where*
# Policies are deployed to every choria-server. Change `mcollective::site_policies` for a node to change the ACL
mcollective::site_policies:
  # for a demo user, used for mco CLI interaction
  - action: "allow"
    callers: "choria=mco.mcollective"
    actions: "*"
    facts: "*"
    classes: "*"
  # smartproxies
  - action: "allow"
    callers: "choria=foreman.%{facts.networking.domain}"
    actions: "*"
    facts: "*"
    classes: "*"
  - action: "allow"
    callers: "choria=openvoxserver.%{facts.networking.domain}"
    actions: "*"
    facts: "*"
    classes: "*"

# this is basically remote execution and only good for demo environments
# do not randomly deploy those plugins in production
# some default plugins:
# https://github.com/choria-io/puppet-mcollective/blob/74db516c307411663354e79ecb3ca3f7bc4cbec9/data/common.yaml#L48-L55
# each plugin/agent is a module that you need to add to your Puppetfile
mcollective::plugin_classes:
  - mcollective_agent_bolt_tasks
  - mcollective_agent_shell
  - mcollective_agent_nettest
  - mcollective_agent_process
  - mcollective_agent_iptables

# don't use legacy cron to cache facts
mcollective::facts_refresh_type: 'systemd'

# used by OpenVox Server & Foreman systems
# set it to latest $major.$minor, omit the patch version
foreman::repo::repo: '3.19'
```

Hiera data for the OpenVox Server:

```yaml
---
# be a choria broker server
choria::broker::network_broker: true

# required to provide stats from the broker
choria::broker::system_password: 'secret'
choria::broker::system_user: 'admin'

# configure a plugin to access the CA
mcollective::plugin_classes:
  - mcollective_agent_puppetca

# required to access stats from the broker
mcollective::client_config:
  plugin.choria.network.system.user: 'admin'
  plugin.choria.network.system.password: 'secret'

# import ssh hostkeys
profiles::base::storeconfigs_enabled: true
```

Data for the Foreman node:

```yaml
---
# import ssh hostkeys
profiles::base::storeconfigs_enabled: true
```

### Puppetfile

```
mod 'theforeman-dns', '12.2.0'
mod 'theforeman-foreman', '30.0.0'
mod 'theforeman-foreman_proxy', '31.0.0'
mod 'saz-ssh', '15.0.0'
mod 'puppet-mosquitto', :latest
mod 'puppet-redis', '13.0.0'
mod 'theforeman/puppetserver_foreman', :latest

# latest choria* module releases aren't published to forge.puppet.com, so we use git tags
mod 'choria-choria',
  git: 'https://github.com/choria-io/puppet-choria',
  ref: '0.32.1'
mod 'choria-mcollective',
  git: 'https://github.com/choria-io/puppet-mcollective',
  ref: '0.15.0'
mod 'choria-mcollective_choria',
  git: 'https://github.com/choria-plugins/mcollective_choria',
  ref: '0.23.0'
mod 'choria-mcollective_agent_puppet',
  git: 'https://github.com/choria-plugins/puppet-agent',
  ref: '2.5.0'
mod 'choria-mcollective_agent_puppetca',
  git: 'https://github.com/choria-plugins/puppetca-agent',
  ref: '4.1.0'
mod 'choria-mcollective_agent_package',
  git: 'https://github.com/choria-plugins/package-agent',
  ref: '5.5.1'
mod 'choria-mcollective_agent_service',
  git: 'https://github.com/choria-plugins/service-agent',
  ref: '4.1.0'
mod 'choria-mcollective_agent_filemgr',
  git: 'https://github.com/choria-plugins/filemgr-agent',
  ref: '2.1.0'
mod 'choria-mcollective_util_actionpolicy',
  git: 'https://github.com/choria-plugins/action-policy',
  ref: '3.3.0'
mod 'choria-mcollective_agent_bolt_tasks',
  git: 'https://github.com/choria-plugins/tasks-agent',
  ref: '0.22.0'
mod 'choria-mcollective_agent_shell',
  git: 'https://github.com/choria-plugins/shell-agent',
  ref: '1.2.1'
mod 'choria-mcollective_agent_nettest',
  git: 'https://github.com/choria-plugins/nettest-agent',
  ref: '4.1.0'
mod 'choria-mcollective_agent_process',
  git: 'https://github.com/choria-plugins/process-agent',
  ref: '4.1.0'
mod 'choria-mcollective_agent_iptables',
  git: 'https://github.com/choria-plugins/iptables-agent',
  ref: '4.1.0'
```

### OpenVox Code

Base profile, assign this to all nodes

```puppet
class profiles::base {
  # set this to true in Hiera for all smartproxies
  Boolean $storeconfigs_enabled  = false,
) {
  # writes all ssh hostkeys into OpenVoxDB. Allows smartproxies to connect to all nodes while validating hostkeys
  class { 'ssh':
    client_storeconfigs_enabled => $storeconfigs_enabled, # collects exported resources
    server_storeconfigs_enabled => true, # exports resources
    validate_sshd_file          => true,
    server_options              => { 'PermitRootLogin' => 'without-password', },
  }
  contain ssh

  # adds the foreman smartproxy ssh key to the root user at all nodes
  # openbolt will use this key for the ssh transport
  include 'foreman_proxy::plugin::remote_execution::ssh_user'

  # configures choria and mcollective
  contain choria

  # This is not required. But it was hard to write and I want to distribute it into the world
  # People like to reuse agent certificates for various things.
  # It helps if the certificate contains all IP addresses
  $all_ips = $facts['networking']['interfaces']       # get a hash for all interfaces
  .filter |$name, $data| { $name != 'lo' }            # remove lo interface
  .map |$name, $data| { [$data['ip'], $data['ip6']] } # get all ips as array
  .flatten                                            # flatten the array
  .delete_undef_values                                # delete undef (in case we don't have IPv6
  .filter |$ip| { $ip !~ /(?i:^fe80)/ }               # Remove link-locale addresses
  .sort                                               # sort it for an idempotent list
  .map |$ip| { "IP:${ip}" }                           # update format for certificates
  class { 'puppet':
    unavailable_runmodes  => ['systemd.timer'],
    agent_server_hostname => "puppet.${facts['networking']['domain']}",
    dns_alt_names         => [$trusted['certname']] + $all_ips,
  }
  contain puppet
}
```

MCO demo user, assign this to one node where you want to explore the `mco` and `choria` CLI
(usually used on the choria-broker, to make local debugging easier)

```puppet
class profiles::mco {
  # profiles::base pulls in choria, and choria includes mcollective
  # mcollective is required for our exec resource
  require profiles::base
  user { 'mco':
    ensure         => 'present',
    system         => true,
    managehome     => true,
    purge_ssh_keys => true,
    shell          => '/bin/bash',
  }
  group { 'mco':
    ensure => 'present',
    system => true,
  }
  exec { 'setup certificate':
    # choria prints the help if command is passed as array?!
    command     => 'choria enroll',
    user        => 'mco',
    group       => 'mco',
    cwd         => '/home/mco',
    path        => $facts['path'],
    provider    => 'shell',
    creates     => '/home/mco/.puppetlabs/etc/puppet/ssl/certs/mco.mcollective.pem',
    # one would assume that you have those environnment variable with provider=shell
    environment => ['USER=mco','HOME=/home/mco',],
    require     => Class['mcollective'],
  }
}
```

smartproxy profile, assign this to the Foreman box and to the OpenVox Server.
**As a bonus this works with Puppet Enterprise**

```
class profiles::foreman_proxy {
  # foreman_proxy module doesn't create the repo
  require foreman::repo

  # On an OpenVox Server, the private key is owned by `puppet:puppet` and `foreman-proxy` is part of that group, so it can read the private key
  # on systems with just a OpenVox-Agent, the private key is owned by `root:root`
  # so we need to copy the priv key into the foreman-proxy dir
  $foreman_priv_key = "/etc/foreman-proxy/${facts['networking']['fqdn']}.pem"
  file { $foreman_priv_key:
    ensure => 'file',
    source => $ssl_key,
    owner  => 'foreman-proxy',
    group  => 'foreman-proxy',
    mode   => '0400',
    notify => Service['foreman-proxy'],
  }
  class { 'foreman_proxy':
    puppet           => true,
    puppetca         => true,
    tftp             => false,
    dhcp             => false,
    dns              => false,
    bmc              => false,
    realm            => false,
    trusted_hosts    => ["foreman.${facts['networking']['domain']}"],
    foreman_base_url => "https://foreman.${facts['networking']['domain']}",
    ssl_key          => $foreman_priv_key,
    puppet_ssl_key   => $foreman_priv_key,
    log              => 'JOURNAL',
  }
  contain foreman_proxy
  include foreman_proxy::plugin::openbolt

  # create an ssh key for the foreman-proxy user
  contain foreman_proxy::plugin::remote_execution::script

  # setup ssh defaults for openbolt to use the key from ↑
  ssh::client::config::user { 'foreman-proxy-bolt':
    ensure              => present,
    user                => 'foreman-proxy',
    user_home_dir       => '/usr/share/foreman-proxy',
    manage_user_ssh_dir => false,
    options             => {
      'Host *' => {
        'IdentityFile' => '~/.ssh/id_rsa_foreman_proxy',
        'User'         => 'root',
      },
    },
    require             => Class['foreman_proxy::plugin::remote_execution::script'], # creates ~/.ssh/id_rsa_foreman_proxy
  }
}
```

## Further documentation

* Choria [can use SRV records](https://choria.io/docs/deployment/dns/) to discover the OpenVoxDB and OpenVox Server FQDNs and ports. But they are a bit uncommon in demo environments, so we use Hiera instead.
* OpenVox also supports SRV records for [the server option](https://docs.openvoxproject.org/openvox-server/8.x/scaling_puppet_server.html#using-dns-srv-records), [the CA](https://docs.openvoxproject.org/openvox-server/8.x/scaling_puppet_server.html#pointing-dns-srv-records-at-a-central-ca)
