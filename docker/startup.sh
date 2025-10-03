#!/bin/bash

# SSTP VPN Server Startup Script for Docker
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check required environment variables
check_environment() {
    if [[ -z "$VPN_USER" || -z "$VPN_PASS" || -z "$VPS_PUBLIC_IP" ]]; then
        error "Required environment variables not set: VPN_USER, VPN_PASS, VPS_PUBLIC_IP"
    fi
    
    log "Environment variables validated"
    log "VPN User: $VPN_USER"
    log "VPS Public IP: $VPS_PUBLIC_IP"
    log "VPN Subnet: $VPN_SUBNET"
}

# Generate SSL certificate
generate_certificate() {
    log "Generating SSL certificate..."
    
    # Generate self-signed certificate
    openssl req -new -x509 -days 365 -nodes \
        -out /etc/ssl/certs/sstp.crt \
        -keyout /etc/ssl/private/sstp.key \
        -subj "/CN=sstp-vpn" \
        -addext "subjectAltName=IP:$VPS_PUBLIC_IP"
    
    # Set proper permissions
    chmod 600 /etc/ssl/private/sstp.key
    chmod 644 /etc/ssl/certs/sstp.crt
    
    log "SSL certificate generated successfully"
}

# Create accel-ppp configuration
create_config() {
    log "Creating accel-ppp configuration..."
    
    # Extract gateway IP from subnet
    VPN_GATEWAY=$(echo $VPN_SUBNET | sed 's/\.0\/.*$/.1/')
    
    # Create configuration from template
    cat > /etc/accel-ppp.conf << EOF
[modules]
log file
ppp
sstp

[core]
log-error=/var/log/accel-ppp.log
thread-count=2

[sstp]
bind=0.0.0.0:443
cert=/etc/ssl/certs/sstp.crt
key=/etc/ssl/private/sstp.key

[ppp]
verbose=1
mtu=1400
mru=1400
check-ip=0
lcp-echo-interval=30
lcp-echo-failure=3

[auth]
any-login=0
require-authentication=1

[chap-secrets]
# user   password   ip
$VPN_USER  $VPN_PASS  ${VPN_GATEWAY%.*}.2

[ip-pool]
gw-ip-address=$VPN_GATEWAY
${VPN_GATEWAY%.*}.2-${VPN_GATEWAY%.*}.200

[dns]
dns1=$DNS1
dns2=$DNS2
EOF

    log "Configuration created successfully"
}

# Configure IP forwarding
configure_ip_forwarding() {
    log "Configuring IP forwarding..."
    
    # Enable IP forwarding
    echo "net.ipv4.ip_forward=1" > /proc/sys/net/ipv4/ip_forward
    
    # Get the main network interface (eth0 in Docker)
    MAIN_INTERFACE="eth0"
    
    # Configure NAT
    iptables -t nat -A POSTROUTING -s $VPN_SUBNET -o $MAIN_INTERFACE -j MASQUERADE
    
    # Allow forwarding for VPN subnet
    iptables -A FORWARD -s $VPN_SUBNET -j ACCEPT
    iptables -A FORWARD -d $VPN_SUBNET -j ACCEPT
    
    log "IP forwarding configured"
}

# Configure basic firewall
configure_firewall() {
    log "Configuring basic firewall..."
    
    # Allow established connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Allow SSTP (port 443)
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    
    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT
    
    # Drop other incoming connections
    iptables -A INPUT -j DROP
    
    log "Firewall configured"
}

# Start accel-ppp service
start_service() {
    log "Starting accel-ppp service..."
    
    # Start accel-ppp in foreground
    exec accel-ppp -c /etc/accel-ppp.conf
}

# Signal handler for graceful shutdown
shutdown_handler() {
    log "Received shutdown signal, stopping services..."
    
    # Kill accel-ppp process
    pkill -f accel-ppp || true
    
    # Wait a moment for graceful shutdown
    sleep 2
    
    log "Services stopped"
    exit 0
}

# Set up signal handlers
trap shutdown_handler SIGTERM SIGINT

# Main execution
main() {
    log "Starting SSTP VPN Server container..."
    
    check_environment
    generate_certificate
    create_config
    configure_ip_forwarding
    configure_firewall
    start_service
}

# Run main function
main "$@"
