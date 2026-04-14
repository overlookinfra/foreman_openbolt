#!/bin/bash
# Copy the bind-mounted public key into the openbolt user's authorized_keys
# with correct ownership and permissions. sshd refuses keys when the
# file or parent directory is writable by anyone other than the owner.
set -e

cp /tmp/id_rsa.pub /home/openbolt/.ssh/authorized_keys
chown openbolt:openbolt /home/openbolt/.ssh/authorized_keys
chmod 600 /home/openbolt/.ssh/authorized_keys

exec /usr/sbin/sshd -D
