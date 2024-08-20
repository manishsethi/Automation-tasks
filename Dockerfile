# # Use the official Ubuntu image as a base
# FROM ubuntu:24.04

# # Set the environment variable for non-interactive package installation
# ENV DEBIAN_FRONTEND=noninteractive

# # Set the working directory
# WORKDIR /app

# # Install necessary packages
# RUN apt-get update && apt-get install -y --no-install-recommends \
#     git git-lfs ccache cmake rpm openssh-client sudo gcc g++ ninja-build systemd && \
#     rm -rf /var/lib/apt/lists/*

# # Create necessary directories and symlinks for systemd
# RUN mkdir -p /run/systemd/system && \
#     ln -sf /lib/systemd/systemd /sbin/init && \
#     ln -sf /run/systemd /var/run/systemd

# # Copy entire project directory into the image
# COPY . /app

# # Set systemd as the entry point
# VOLUME ["/tmp", "/run"]


# # Install dbus
# RUN apt-get update && apt-get install -y dbus

# # Set up dbus
# RUN mkdir -p /var/run/dbus /run/dbus && \
#     dbus-uuidgen > /etc/machine-id

# # Copy a custom dbus policy file to allow the required operations
# COPY dbus-policy.conf /etc/dbus-1/system.d/dbus-policy.conf

# # Ensure dbus is running as a service
# CMD ["sh", "-c", "dbus-daemon --system --nofork & while true; do sleep 1000; done"]

# ENTRYPOINT ["/lib/systemd/systemd"]

# Use openSUSE Leap 15.5 as the base image
FROM opensuse/leap:15.5

# Set the working directory
WORKDIR /app

# Refresh repositories
RUN zypper --non-interactive refresh

# Install core system tools and systemd
RUN zypper --non-interactive install --no-recommends --allow-vendor-change --auto-agree-with-licenses --force-resolution \
    sudo systemd && \
    zypper clean -a

# Install development tools, replacing rpmbuild and dbus with their respective packages
RUN zypper --non-interactive install --no-recommends --allow-vendor-change --auto-agree-with-licenses --force-resolution \
    git git-lfs ccache cmake openssh gcc13 gcc-c++ ninja dbus-1 systemd-devel && \
    zypper clean -a

# Create necessary directories and symlinks for systemd
RUN mkdir -p /run/systemd /run/systemd/system && \
    ln -sf /usr/lib/systemd/systemd /sbin/init && \
    ln -sf /run/systemd /var/run/systemd

# Create necessary directories for dbus and generate machine ID
RUN mkdir -p /run/dbus && \
    dbus-uuidgen > /etc/machine-id

# Copy the entire project directory into the image
COPY . /app

# Expose required volumes for systemd and dbus
VOLUME ["/tmp", "/run", "/sys/fs/cgroup"]

# Set systemd as the entry point
ENTRYPOINT ["/usr/lib/systemd/systemd"]

# Optionally start dbus and other services by default
CMD ["/usr/lib/systemd/systemd", "--system"]


