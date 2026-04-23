# Setting Up Choria for OpenBolt Testing

This guide covers installing and configuring Choria on a Foreman-managed
infrastructure so you can test the Choria transport with OpenBolt. It
assumes Foreman is already running with an OpenVox Server (or Puppet
Server) and CA, and that your managed nodes have signed OpenVox/Puppet
agent certificates.

Choria uses your existing OpenVox/Puppet CA for all TLS. No separate PKI
is needed.

## Architecture

| Role | Host | What gets installed |
|---|---|---|
| Broker + Client | Foreman primary (Foreman, OpenVox/Puppet Server, smart proxy, OpenBolt) | `choria` package (Go binary, embedded NATS on port 4222), `choria` CLI, `choria-mcorpc-support` gem (bundled in OpenBolt) |
| Server | Each managed node | `choria` package (includes `bolt_tasks` agent) + `shell` agent (optional) |

## Prerequisites

- **OpenBolt 5.5 or later** (the Choria transport is not available in Puppet Bolt)
- Foreman with a working OpenVox Server (or Puppet Server) and CA
- Managed nodes with signed OpenVox/Puppet agent certificates
- Certnames that match FQDNs (the default for both OpenVox/Puppet and Choria)
- Port 4222 open from all nodes to the Foreman primary
- Port 8140 open from all nodes to the OpenVox/Puppet Server (task file downloads)

## Step 1: Install modules

### With a Puppetfile (r10k / Code Manager)

r10k does not resolve transitive dependencies automatically, so all
modules must be listed explicitly. Add to your Puppetfile:

```ruby
# Choria core
mod 'choria/choria',                        :latest
mod 'choria/mcollective',                   :latest
mod 'choria/mcollective_choria',            :latest

# Choria standard agents (dependencies of choria/choria)
mod 'choria/mcollective_agent_filemgr',     :latest
mod 'choria/mcollective_agent_package',     :latest
mod 'choria/mcollective_agent_puppet',      :latest
mod 'choria/mcollective_agent_service',     :latest
mod 'choria/mcollective_util_actionpolicy', :latest

# Task agent configuration (agent code ships with choria, module provides the Puppet class)
mod 'choria/mcollective_agent_bolt_tasks',  :latest

# Shell agent for alternative task execution (>= 1.2.1, GitHub only)
mod 'mcollective_agent_shell',
  git: 'https://github.com/choria-plugins/shell-agent',
  ref: '1.2.1'

# Dependencies (skip any already in your environment)
mod 'puppetlabs/stdlib',   :latest
mod 'puppetlabs/apt',      :latest
mod 'puppetlabs/concat',   :latest
mod 'puppetlabs/inifile',  :latest
mod 'puppet/systemd',      :latest
```

The `bolt_tasks` agent code ships with the `choria` package, but the
`choria/mcollective_agent_bolt_tasks` Puppet module is still needed to
provide the class that `mcollective::plugin_classes` includes for
configuration.

You also need any task modules you want to run in the environment. The
`bolt_tasks` agent downloads task files from the OpenVox/Puppet Server
at runtime. For example, to use the `facts` task:

```ruby
mod 'puppetlabs/facts',    :latest
```

Then deploy:

```bash
r10k deploy environment production
```

### Without a Puppetfile (puppet module install)

`puppet module install` resolves Forge dependencies automatically. Modules
install into `/etc/puppetlabs/code/environments/production/modules/` by
default.

```bash
puppet module install choria-choria
puppet module install choria-mcollective_agent_bolt_tasks
```

Install any task modules you want to run. The `bolt_tasks` agent
downloads task files from the OpenVox/Puppet Server at runtime:

```bash
puppet module install puppetlabs-facts
```

For the shell agent (GitHub-only at the required version):

```bash
cd /etc/puppetlabs/code/environments/production/modules/
git clone https://github.com/choria-plugins/shell-agent.git mcollective_agent_shell
cd mcollective_agent_shell && git checkout 1.2.1
```

## Step 2: Verify server authorization rules

The `bolt_tasks` agent downloads task files from the OpenVox/Puppet
Server via the `/puppet/v3/file_content` and `/puppet/v3/tasks`
endpoints. These are allowed for all authenticated nodes in the default
`auth.conf`. If you have customized your server's
`/etc/puppetlabs/puppetserver/conf.d/auth.conf`, verify that these
endpoints are not blocked.

## Step 3: Hiera data

Add the following to your common Hiera data. The `choria` module defaults
to `manage_package_repo: true` and `server: true`, so those do not need
to be set explicitly. The `puppetserver_port` defaults to `8140`.

`/etc/puppetlabs/code/environments/production/data/common.yaml`:

```yaml
choria::server_config:
  plugin.choria.middleware_hosts: "primary.example.com:4222"
  plugin.choria.puppetserver_host: "primary.example.com"
  plugin.choria.use_srv: false

mcollective::plugin_classes:
  - mcollective_agent_bolt_tasks
  - mcollective_agent_shell

mcollective_choria::config:
  security.certname_whitelist: "/.*/"

mcollective::site_policies:
  - action: "allow"
    callers: "/.*/"
    actions: "*"
    facts: "*"
    classes: "*"
```

Replace `primary.example.com` with your OpenVox/Puppet Server FQDN. If
your server resolves as `puppet` (the default), you can omit
`plugin.choria.puppetserver_host`.

The `certname_whitelist` and `site_policies` above allow all callers for
testing. In production, replace `/.*/` with a more restrictive pattern
such as `/.*\.example\.com$/` to limit accepted certnames and callers.

## Step 4: Site manifest

Add Choria classes to your node definitions in
`/etc/puppetlabs/code/environments/production/manifests/site.pp`:

```puppet
# Foreman primary: broker + server
node 'primary.example.com' {
  include choria
  include choria::broker
}

# Managed nodes: server only
node default {
  include choria
}
```

The `choria::broker` class enables the embedded NATS broker. It only
needs to be included on the primary.

## Step 5: Deploy

On the **primary**, run Puppet first (sets up the broker):

```bash
puppet agent -t
```

Then on **each managed node**:

```bash
puppet agent -t
```

Verify `choria-server` is running on **each node** (including the
primary):

```bash
systemctl status choria-server
```

## Step 6: Verify connectivity

On the **primary**, verify that all nodes are reachable via Choria.
The `choria ping` command works as root using the server config:

```bash
choria ping
```

All nodes (including the primary) should respond with their FQDNs.
Confirm the `bolt_tasks` agent is loaded on the managed nodes:

```bash
choria rpc rpcutil agent_inventory -I node1.example.com
```

Look for `bolt_tasks` in the agents list.

## Step 7: Test with OpenBolt directly

On the **primary**, test the OpenBolt path as the `foreman-proxy` user.
The `--choria-mcollective-certname` flag is needed because the
`choria-mcorpc-support` library identifies non-root users as
`<username>.mcollective`, which does not match the host's certificate CN.
When running through the smart proxy, this is handled automatically.

```bash
cd /tmp && sudo -u foreman-proxy bolt task run facts \
  --targets node1.example.com,node2.example.com \
  --transport choria \
  --choria-brokers primary.example.com:4222 \
  --choria-ssl-cert /etc/puppetlabs/puppet/ssl/certs/$(puppet config print certname).pem \
  --choria-ssl-key /etc/puppetlabs/puppet/ssl/private_keys/$(puppet config print certname).pem \
  --choria-ssl-ca /etc/puppetlabs/puppet/ssl/certs/ca.pem \
  --choria-mcollective-certname $(puppet config print certname)
```

Replace `primary.example.com` with your OpenVox/Puppet Server FQDN. The
port defaults to 4222 if omitted. Do not use the `nats://` prefix. If
`--choria-brokers` is omitted entirely, the Choria client checks the
config file, then SRV records, then falls back to `puppet:4222`.

## Step 8: Configure Foreman

Once the `smart_proxy_openbolt` and `foreman_openbolt` Choria support is
deployed, select "Choria" in the transport dropdown on the Launch Task
page. The one setting you may need to evaluate is **Choria Brokers**
(under Administer > Settings > OpenBolt). If `puppet` resolves to the
broker host or SRV records are configured, it can be left blank.
Otherwise, set it to your broker's address:

| Setting | Example value |
|---|---|
| Choria Brokers | `primary.example.com:4222` |

Other Choria settings (SSL, the default config file, certname) are
derived automatically by the proxy and can be ignored unless your
Choria configuration requires customization. The default config file
used by the proxy is at `lib/smart_proxy_openbolt/config/choria-client.conf`
in the `smart_proxy_openbolt` gem.

### Advanced: custom Choria configuration file

If you need full control over the MCollective client configuration, set
the "Choria Config File" setting under Administer > Settings > OpenBolt to the path of your
custom configuration file. When a custom config file is provided, the
proxy does not inject SSL defaults (the config file is expected to
handle SSL on its own). If you also set the Choria SSL settings in
Foreman, those override the values in the config file.

## Important notes

- **Target names must match Choria identities.** Use the FQDNs shown by
  `choria ping`. Mismatches cause silent timeouts.
- **Task modules must exist on the OpenVox/Puppet Server** in the
  production environment (or whichever environment you configure via the
  Choria Puppet Environment setting). The `bolt_tasks` agent downloads
  task files from the OpenVox/Puppet Server at runtime.
- **Certnames must match FQDNs** by default in Choria.
- **The broker listens on port 4222.** For clustered deployments, port
  4223 handles inter-broker communication.

## Troubleshooting

**`choria ping` returns no results:**
- Verify `choria-server` is running on the target nodes
  (`systemctl status choria-server`).
- Verify the broker is running on the primary
  (`systemctl status choria-broker` or check port 4222).
- Check that `plugin.choria.middleware_hosts` in the node config points
  to the correct broker FQDN and port.
- Verify the client certificate is signed by the same OpenVox/Puppet CA
  (`openssl verify -CAfile ca.pem client.pem`).

**`bolt task run` fails with "no nodes replied":**
- Confirm the target names match the identities shown by `choria ping`
  exactly.
- Verify `bolt_tasks` appears in the agent list
  (`choria rpc rpcutil agent_inventory -I <target>`).

**Task downloads fail:**
- Confirm the OpenVox/Puppet Server authorization rules from Step 2 are
  not blocked (`puppetserver reload` after any auth.conf changes).
- Verify the task module exists in the production environment
  modulepath on the OpenVox/Puppet Server.

**Agent not found after install:**
- Restart `choria-server` on the target node. Choria only loads agents
  at startup.

## References

- [Choria Deployment Requirements](https://choria.io/docs/deployment/requirements/)
- [Choria Network Broker](https://choria.io/docs/deployment/broker/)
- [Choria Server Configuration](https://choria.io/docs/configuration/choria_server/)
- [Choria Security Model](https://choria.io/docs/concepts/security/)
- [Choria First User Setup](https://choria.io/docs/deployment/first-user/)
- [Choria Puppet Tasks Configuration](https://choria.io/docs/tasks/configuration/)
