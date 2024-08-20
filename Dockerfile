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

# Install necessary packages including dbus, and handle dependency issues by allowing vendor change and forcing resolution
RUN zypper --non-interactive install --no-recommends --allow-vendor-change --auto-agree-with-licenses --force-resolution \
    git git-lfs ccache cmake rpmbuild openssh sudo gcc13 gcc-c++ ninja systemd dbus &&  \
    zypper clean -a

# Create necessary directories and symlinks for systemd
RUN mkdir -p /run/systemd /run/systemd/system && \
    ln -sf /usr/lib/systemd/systemd /sbin/init && \
    ln -sf /run/systemd /var/run/systemd

# Create necessary directories for dbus
RUN mkdir -p /run/dbus && \
    dbus-uuidgen > /etc/machine-id

# Copy entire project directory into the image
COPY . /app

# Add a repository and refresh the package cache
RUN zypper ar -fG dir:/app/repo/3rdParty/leap/ 3rdParty

# Ensure systemd is the entry point and dbus starts with it
VOLUME ["/tmp", "/run", "/sys/fs/cgroup"]
ENTRYPOINT ["/usr/lib/systemd/systemd"]

# Set dbus to start as a service
CMD ["/usr/lib/systemd/systemd", "--system", "--unit=dbus.service"]