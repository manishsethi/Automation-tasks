# Use the official Ubuntu image as a base
FROM ubuntu:24.04

# Set the environment variable for non-interactive package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set the working directory
WORKDIR /app

# Install necessary packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs ccache cmake rpm openssh-client sudo gcc g++ ninja-build systemd && \
    rm -rf /var/lib/apt/lists/*

# Create necessary directories and symlinks for systemd
RUN mkdir -p /run/systemd/system && \
    ln -sf /lib/systemd/systemd /sbin/init && \
    ln -sf /run/systemd /var/run/systemd

# Copy entire project directory into the image
COPY . /app

# Set systemd as the entry point
VOLUME ["/tmp", "/run"]


# Install dbus
RUN apt-get update && apt-get install -y dbus

# Set up dbus
RUN mkdir -p /var/run/dbus /run/dbus && \
    dbus-uuidgen > /etc/machine-id

# Copy a custom dbus policy file to allow the required operations
COPY dbus-policy.conf /etc/dbus-1/system.d/dbus-policy.conf

# Ensure dbus is running as a service
CMD ["sh", "-c", "dbus-daemon --system --nofork & while true; do sleep 1000; done"]

ENTRYPOINT ["/lib/systemd/systemd"]


