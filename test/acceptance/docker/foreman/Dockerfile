# Foreman base image for acceptance testing.
# This Dockerfile only installs packages. foreman-installer is run
# separately via `docker run --hostname` (see Rakefile) because it
# requires a valid FQDN and systemd, neither of which are available
# during `docker build`.
#
# The final image is created by committing the container after
# foreman-installer completes. Plugin RPMs are installed at runtime
# via setup.sh.
FROM --platform=linux/amd64 rockylinux:9

ARG FOREMAN_VERSION=3.18

# Locale
RUN dnf install -y glibc-langpack-en && dnf clean all
ENV LANG=en_US.UTF-8
ENV PATH="$PATH:/opt/puppetlabs/bin:/opt/puppetlabs/server/bin"

# Enable module streams
RUN dnf -y module enable nodejs:22 postgresql:16

# Add Foreman and OpenVox repos
RUN dnf install -y \
      "https://yum.theforeman.org/releases/${FOREMAN_VERSION}/el9/x86_64/foreman-release.rpm" \
      https://yum.voxpupuli.org/openvox8-release-el-9.noarch.rpm && \
    dnf clean all

# Install foreman-installer, OpenBolt, and OpenVox (agent + server)
RUN dnf install -y \
      foreman-installer \
      jq \
      openbolt \
      openssh-clients \
      openvox-agent \
      openvox-server && \
    dnf clean all

# Fix NSS for container environment. Rocky 9 defaults to "sss files systemd"
# but sssd isn't running, causing getpwuid(0) to fail in JRuby/puppetserver.
RUN sed -i 's/^passwd:.*/passwd:     files/' /etc/nsswitch.conf && \
    sed -i 's/^shadow:.*/shadow:     files/' /etc/nsswitch.conf && \
    sed -i 's/^group:.*/group:      files/' /etc/nsswitch.conf


CMD ["/usr/sbin/init"]
