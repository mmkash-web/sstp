# Dockerfile for SSTP VPN Server
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV VPN_USER=""
ENV VPN_PASS=""
ENV VPS_PUBLIC_IP=""
ENV VPN_SUBNET="10.10.10.0/24"
ENV DNS1="1.1.1.1"
ENV DNS2="8.8.8.8"

# Install required packages
RUN apt-get update && \
    apt-get install -y \
    accel-ppp \
    openssl \
    iptables \
    net-tools \
    iputils-ping \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /etc/ssl/certs /etc/ssl/private /var/log

# Copy configuration files
COPY config/accel-ppp.conf /etc/accel-ppp.conf.template
COPY scripts/generate-cert.sh /usr/local/bin/generate-cert.sh
COPY scripts/setup-firewall.sh /usr/local/bin/setup-firewall.sh
COPY scripts/add-user.sh /usr/local/bin/add-user.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/generate-cert.sh
RUN chmod +x /usr/local/bin/setup-firewall.sh
RUN chmod +x /usr/local/bin/add-user.sh

# Create startup script
COPY docker/startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

# Expose SSTP port
EXPOSE 443

# Set working directory
WORKDIR /etc

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD netstat -tlnp | grep :443 || exit 1

# Start the service
CMD ["/usr/local/bin/startup.sh"]
