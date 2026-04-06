# Base test image: Foreman + system deps on Rocky Linux 9.
# This image is stable for a given Foreman version and does not
# depend on any foreman_openbolt code. All plugin wiring happens
# at runtime via the rake test:up task.
#
# Build:
#   FOREMAN_REF=3.18-stable docker compose -f test/docker/docker-compose.yml build test

FROM rockylinux:9

# System packages -- cached across all Foreman versions.
RUN dnf module enable -y nodejs:22 postgresql:16 && \
    dnf install -y \
      ruby ruby-devel rubygem-bundler \
      gcc gcc-c++ make \
      postgresql-devel postgresql \
      libffi-devel \
      nodejs npm \
      git-core \
      redhat-rpm-config && \
    dnf clean all

ARG FOREMAN_REF=3.18-stable

# Clone Foreman at the specified ref (tag, branch, or SHA).
RUN git init /opt/foreman

WORKDIR /opt/foreman

RUN git remote add origin https://github.com/theforeman/foreman.git && \
    git fetch --depth=1 origin ${FOREMAN_REF} && \
    git checkout FETCH_HEAD

# Configure database for the test container.
RUN printf "test:\n  adapter: postgresql\n  host: db\n  port: 5432\n  username: foreman\n  password: foreman\n  database: foreman_test\n  encoding: utf8\n  pool: 5\n" \
      > config/database.yml

# Install Foreman's own gems (without the plugin). This is the
# expensive layer but only changes when the Foreman version changes.
ENV BUNDLE_WITHOUT="release console journald libvirt ec2 openstack vmware telemetry"
ENV BUNDLE_PATH="/opt/bundle"
RUN bundle install --jobs=4

COPY test/docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
