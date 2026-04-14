#!/bin/bash
# Prepare the Foreman container for acceptance testing.
# This runs before systemd (PID 1) takes over.
set -e

# Proxy log directory
mkdir -p /var/log/foreman-proxy/openbolt
chown -R foreman-proxy:foreman-proxy /var/log/foreman-proxy

# SSH key for proxy to reach targets
if [ -f /tmp/ssh/id_rsa ]; then
  mkdir -p /opt/foreman-proxy/.ssh
  chown foreman-proxy:foreman-proxy /opt/foreman-proxy /opt/foreman-proxy/.ssh
  cp /tmp/ssh/id_rsa /opt/foreman-proxy/.ssh/id_rsa
  chown foreman-proxy:foreman-proxy /opt/foreman-proxy/.ssh/id_rsa
  chmod 600 /opt/foreman-proxy/.ssh/id_rsa
fi

# Deploy fixture modules for acceptance tasks
if [ -d /opt/fixtures/modules ]; then
  mkdir -p /etc/puppetlabs/code/environments/production/modules
  cp -r /opt/fixtures/modules/* /etc/puppetlabs/code/environments/production/modules/
fi

# Hand off to systemd
exec /usr/sbin/init
