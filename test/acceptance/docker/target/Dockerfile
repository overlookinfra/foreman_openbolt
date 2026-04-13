FROM rockylinux:9

ARG OPENVOX_RELEASE=8

RUN dnf install -y \
      openssh-server \
      openssh-clients \
      sudo \
      jq \
      https://yum.voxpupuli.org/openvox${OPENVOX_RELEASE}-release-el-9.noarch.rpm && \
    dnf install -y openvox-agent && \
    dnf clean all

RUN useradd -m openbolt && \
    echo 'openbolt:openbolt' | chpasswd && \
    usermod -aG wheel openbolt && \
    echo 'openbolt ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/openbolt

RUN mkdir -p /home/openbolt/.ssh && \
    chmod 700 /home/openbolt/.ssh && \
    chown -R openbolt:openbolt /home/openbolt

RUN ssh-keygen -A

COPY target/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
