# Use the official Ubuntu image as a base
FROM ubuntu:latest

# Install dbus
RUN apt-get update && apt-get install -y dbus

# Set up dbus
RUN mkdir -p /var/run/dbus && \
    dbus-uuidgen > /etc/machine-id

# Run a basic dbus command as a test (optional, for manual testing)
CMD ["dbus-daemon", "--system", "--nofork"]