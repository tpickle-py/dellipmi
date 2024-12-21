# Use Alpine Linux as base for a smaller image
FROM alpine:3.19

# Install required packages
RUN apk add --no-cache \
    ipmitool=1.8.19-r1 \
    bash=5.2.21-r0 \
    curl=8.9.1-r1 \
    jq=1.7.1-r0 \
    openssl=3.1.7-r1 \
    ca-certificates=20240226-r0 \
    nmap=7.94-r0 \
    nmap-scripts=7.94-r0

# Create directories for scripts and config
WORKDIR /opt/ipmi
RUN mkdir -p /opt/ipmi/config /opt/ipmi/scripts

# Create a config directory for storing credentials securely
RUN mkdir -p /opt/ipmi/config/credentials \
    && chmod 700 /opt/ipmi/config/credentials

# Copy the IPMI management scripts
COPY scripts/dell-ipmi-shutdown.sh /opt/ipmi/scripts/
COPY scripts/remote-ipmi-manager.sh /opt/ipmi/scripts/

# Make scripts executable and add to PATH
RUN chmod +x /opt/ipmi/scripts/*.sh && \
    ln -s /opt/ipmi/scripts/remote-ipmi-manager.sh /usr/local/bin/ipmi-manager && \
    ln -s /opt/ipmi/scripts/dell-ipmi-shutdown.sh /usr/local/bin/ipmi-power

# Add scripts directory to PATH
ENV PATH="/opt/ipmi/scripts:${PATH}"

# Create a healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep ipmitool || exit 1

# Set the entrypoint to bash and keep the container running
ENTRYPOINT ["/bin/bash", "-c", "while true; do sleep 1000; done"]
