FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install OpenSSH server and basic utilities
RUN apt-get update && \
    apt-get install -y \
    openssh-server \
    sudo \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Create privilege separation directory for SSH
RUN mkdir -p /run/sshd

# Create ubuntu user for SSH access with sudo privileges
RUN useradd -m -s /bin/bash -G sudo ubuntu

# Configure SSH for secure gateway access:
# - Disable password authentication (key-based only)
# - Disable root login
# - Enable public key authentication
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# Create .ssh directory for ubuntu user
RUN mkdir -p /home/ubuntu/.ssh && \
    chmod 700 /home/ubuntu/.ssh && \
    chown ubuntu:ubuntu /home/ubuntu/.ssh

# Copy authorized_keys from default-key directory
COPY default-key/authorized_keys /home/ubuntu/.ssh/authorized_keys
RUN chmod 600 /home/ubuntu/.ssh/authorized_keys && \
    chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys

# Expose SSH port (will be mapped to 8222 on host)
EXPOSE 22

# Start SSH service
CMD ["/usr/sbin/sshd", "-D"]
