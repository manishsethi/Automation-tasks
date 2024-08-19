# Use the official Ubuntu image as a base
FROM ubuntu:24.04
# Install dbus
RUN apt-get update && apt-get install -y dbus

# Set up dbus
RUN mkdir -p /var/run/dbus && \
    dbus-uuidgen > /etc/machine-id

# Copy a custom dbus policy file to allow the required operations
COPY dbus-policy.conf /etc/dbus-1/system.d/dbus-policy.conf

# Ensure dbus is running as a service
CMD ["sh", "-c", "dbus-daemon --system --nofork --config-file=/etc/dbus-1/system.conf & while true; do sleep 1000; done"]